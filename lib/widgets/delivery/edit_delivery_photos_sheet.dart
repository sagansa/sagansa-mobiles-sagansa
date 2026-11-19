import 'dart:io';

import 'package:flutter/material.dart';

import '../../providers/delivery_provider.dart';
import '../../services/image_service.dart';
import '../../services/image_upload_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../app_snackbar.dart';
import '../safe_bottom_bar.dart';

/// Bottom sheet untuk admin/super_admin mengganti seluruh foto bukti
/// pengiriman order direct (for=1) — tanpa batasan status order, mengikuti
/// guard backend POST /sales-orders/{id}/delivery-photos. Menggantikan alur
/// lama "hubungi admin backend" dari mobile.
///
/// Seed dari order: foto lama dipasangkan `image_delivery_paths` (path
/// mentah, dikirim ulang ke server) dengan `image_delivery_urls` (URL
/// tampilan). Foto baru di-upload saat simpan; daftar path LENGKAP (lama
/// tersisa + baru) dikirim sebagai pengganti keseluruhan.
class EditDeliveryPhotosSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final DeliveryProvider provider;

  const EditDeliveryPhotosSheet({
    super.key,
    required this.order,
    required this.provider,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> order,
    required DeliveryProvider provider,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditDeliveryPhotosSheet(order: order, provider: provider),
    );
  }

  @override
  State<EditDeliveryPhotosSheet> createState() =>
      _EditDeliveryPhotosSheetState();
}

class _EditDeliveryPhotosSheetState extends State<EditDeliveryPhotosSheet> {
  /// Foto lama: [{path, url}] — path dikirim ulang ke server, url untuk
  /// tampilan network image.
  final List<Map<String, String>> _oldPhotos = [];
  final List<File> _newFiles = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _seedFromOrder();
  }

  void _seedFromOrder() {
    final paths =
        (widget.order['image_delivery_paths'] as List<dynamic>? ?? [])
            .map((p) => p?.toString() ?? '')
            .where((p) => p.isNotEmpty)
            .toList();
    final urls = (widget.order['image_delivery_urls'] as List<dynamic>? ?? [])
        .map((u) => u?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
    final fallbackUrl = widget.order['image_delivery_url']?.toString();

    // Pasangkan path ke url berdasar index; fallback singular untuk respons
    // backend lama yang hanya punya url tanpa paths.
    if (paths.isEmpty && fallbackUrl != null && fallbackUrl.isNotEmpty) {
      _oldPhotos.add({'path': '', 'url': fallbackUrl});
      return;
    }
    for (var i = 0; i < paths.length; i++) {
      _oldPhotos.add({'path': paths[i], 'url': i < urls.length ? urls[i] : ''});
    }
  }

  int get _totalPhotos => _oldPhotos.length + _newFiles.length;

  Future<void> _addPhoto() async {
    final photo = await ImageService.selectAndPickImage(context);
    if (photo == null) return;
    setState(() => _newFiles.add(photo));
  }

  void _removeOldAt(int index) {
    setState(() => _oldPhotos.removeAt(index));
  }

  void _removeNewAt(int index) {
    setState(() => _newFiles.removeAt(index));
  }

  Future<void> _save() async {
    if (_totalPhotos == 0) return;

    // Upload foto baru dulu (pola error per-nomor ala updateDeliveryStatus),
    // lalu kirim daftar path lengkap: lama tersisa + baru.
    final newPathList = <String>[];
    setState(() => _isUploading = true);
    try {
      for (var i = 0; i < _newFiles.length; i++) {
        final path = await ImageUploadService.upload(
          _newFiles[i],
          directory: 'images/Delivery',
        );
        if (path == null) {
          throw Exception('Gagal upload foto ke-${i + 1}.');
        }
        newPathList.add(path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showSnack(e.toString().replaceAll('Exception: ', ''));
      return;
    }

    final allPaths = [
      ..._oldPhotos.map((p) => p['path'] ?? '').where((p) => p.isNotEmpty),
      ...newPathList,
    ];

    try {
      await widget.provider.updateDeliveryPhotos(allPaths);
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnackBar(
        context,
        'Foto bukti pengiriman berhasil diperbarui.',
        background: AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  bool get _isSaving =>
      _isUploading || widget.provider.formState.isUpdatingPhotos;

  void _showSnack(String message) {
    showAppSnackBar(context, message, background: AppColors.error);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom +
        context.systemBottomInset;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Padding(
            padding: AppSpacing.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        color: colorScheme.primary, size: 20),
                    AppSpacing.gapHorizontalSM,
                    Expanded(
                      child: Text(
                        'Ganti Foto Bukti Pengiriman • Order #${widget.order['id']}',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (_totalPhotos == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Belum ada foto. Tambahkan minimal 1 foto bukti pengiriman.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        )
                      else
                        _buildPhotoGrid(colorScheme),
                      AppSpacing.gapVerticalMD,
                      OutlinedButton.icon(
                        onPressed: _addPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: Text(_totalPhotos == 0
                            ? 'Tambah Foto'
                            : 'Tambah Foto Lagi'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                FilledButton.icon(
                  onPressed:
                      (_isSaving || _totalPhotos == 0) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoGrid(ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _totalPhotos,
      itemBuilder: (context, index) {
        if (index < _oldPhotos.length) {
          return _oldPhotoThumb(index, colorScheme);
        }
        return _newPhotoThumb(index - _oldPhotos.length, colorScheme);
      },
    );
  }

  Widget _oldPhotoThumb(int index, ColorScheme colorScheme) {
    final photo = _oldPhotos[index];
    final url = ImageService.buildUrl(photo['url']);

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url == null
                ? const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _removeButton(() => _removeOldAt(index)),
        ),
      ],
    );
  }

  Widget _newPhotoThumb(int index, ColorScheme colorScheme) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _newFiles[index],
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _removeButton(() => _removeNewAt(index)),
        ),
      ],
    );
  }

  Widget _removeButton(VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}
