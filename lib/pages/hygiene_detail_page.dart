import 'package:flutter/material.dart';

import '../models/hygiene_model.dart';
import '../services/hygiene_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';

/// Detail dari sebuah laporan kebersihan: info toko/tanggal/status +
/// daftar tiap ruangan beserta foto, kondisi, dan catatan.
///
/// Menerima [HygieneModel] yang sudah dimuat dari list (backend `index()`
/// sudah eager-load rooms + store + created/approved by), jadi tidak perlu
/// fetch ulang.
class HygieneDetailPage extends StatefulWidget {
  final HygieneModel hygiene;

  const HygieneDetailPage({super.key, required this.hygiene});

  @override
  State<HygieneDetailPage> createState() => _HygieneDetailPageState();
}

class _HygieneDetailPageState extends State<HygieneDetailPage> {
  late HygieneModel _hygiene;
  bool _isSaving = false;

  /// True jika ada mutasi (menilai ruangan) yang mempengaruhi list.
  /// Dikirim ke list saat pop agar list di-refresh.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _hygiene = widget.hygiene;
  }

  Future<void> _markRoom(HygieneRoomModel room, int condition) async {
    setState(() => _isSaving = true);
    try {
      final updated = await HygieneService().updateRoomStatus(room.id, condition);
      if (!mounted) return;
      setState(() {
        final idx = _hygiene.rooms.indexWhere((r) => r.id == room.id);
        if (idx != -1) {
          _hygiene.rooms[idx] = updated;
        }
        _dirty = true;
      });
      if (!mounted) return;
      SnackbarUtils.success(
        context,
        condition == 1
            ? 'Ruangan ditandai Bersih.'
            : condition == 3
                ? 'Ruangan ditandai Kotor.'
                : 'Foto ditandai Tidak Sesuai.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return AppColors.warning;
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope<bool>(
      // Saat user tekan back, kirim _dirty agar list tahu perlu refresh.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _dirty);
      },
      child: Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('Detail Kebersihan')),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMD
            .copyWith(top: AppBarInsets.top(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              elevation: 0,
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.borderRadiusLG,
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: Column(
                  children: [
                    _buildInfoRow(
                        'Toko', _hygiene.storeName ?? '-', theme),
                    const Divider(height: 20),
                    _buildInfoRow('Tanggal', _formatDate(_hygiene.createdAt), theme),
                    const Divider(height: 20),
                    _buildInfoRow(
                        'Dilaporkan oleh', _hygiene.createdByName ?? '-', theme),
                    if (_hygiene.approvedByName != null) ...[
                      const Divider(height: 20),
                      _buildInfoRow(
                          'Disetujui oleh', _hygiene.approvedByName!, theme),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: _statusColor(_hygiene.status)
                                .withValues(alpha: 0.1),
                            borderRadius: AppSpacing.borderRadiusXL,
                          ),
                          child: Text(
                            _hygiene.statusLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _statusColor(_hygiene.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_hygiene.notes != null && _hygiene.notes!.isNotEmpty) ...[
              AppSpacing.gapVerticalMD,
              Card(
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusLG,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      AppSpacing.gapVerticalSM,
                      Text(
                        FormatUtils.stripHtml(_hygiene.notes!),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            AppSpacing.gapVerticalLG,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Ruangan',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            AppSpacing.gapVerticalSM,
            if (_hygiene.rooms.isEmpty)
              Center(
                child: Padding(
                  padding: AppSpacing.paddingLG,
                  child: Text(
                    'Tidak ada data ruangan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
                children: _hygiene.rooms.map((room) {
                  final imageUrl = room.imageUrl;
                  final hasNotes = room.notes != null && room.notes!.isNotEmpty;

                  return ClipRRect(
                    borderRadius: AppSpacing.borderRadiusMD,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Foto ruangan (1:1 aspect ratio)
                        imageUrl != null
                            ? GestureDetector(
                                onTap: () => _showImage(context, imageUrl),
                                child: Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppColors.info,
                                    ),
                                  ),
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.info,
                                ),
                              ),

                        // Scrim atas: Nama ruangan
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Text(
                              room.roomName ?? 'Ruangan',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(blurRadius: 2, color: Colors.black54)
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // Catatan ruangan (jika ada)
                        if (hasNotes)
                          Positioned(
                            top: 34,
                            left: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: AppSpacing.borderRadiusXS,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.notes,
                                      size: 12, color: Colors.amberAccent),
                                  AppSpacing.gapHorizontalXS,
                                  Expanded(
                                    child: Text(
                                      room.notes!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Scrim bawah: Tombol Aksi Kondisi (Bersih | Kotor | Tdk Sesuai)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.85),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                _conditionButton(
                                  context: context,
                                  label: 'Bersih',
                                  color: AppColors.success,
                                  active: room.condition == 1,
                                  onTap: () => _markRoom(room, 1),
                                  saving: _isSaving,
                                  theme: theme,
                                ),
                                AppSpacing.gapHorizontalXS,
                                _conditionButton(
                                  context: context,
                                  label: 'Kotor',
                                  color: AppColors.error,
                                  active: room.condition == 3,
                                  onTap: () => _markRoom(room, 3),
                                  saving: _isSaving,
                                  theme: theme,
                                ),
                                AppSpacing.gapHorizontalXS,
                                _conditionButton(
                                  context: context,
                                  label: 'Tdk Sesuai',
                                  color: AppColors.info,
                                  active: room.condition == 4,
                                  onTap: () => _markRoom(room, 4),
                                  saving: _isSaving,
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      ),
    );
  }

  Widget _conditionButton({
    required BuildContext context,
    required String label,
    required Color color,
    required bool active,
    required VoidCallback onTap,
    required bool saving,
    required ThemeData theme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: saving ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? color
                : Colors.black.withValues(alpha: 0.45),
            borderRadius: AppSpacing.borderRadiusXS,
            border: Border.all(
              color: active ? color : Colors.white38,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _showImage(BuildContext context, String url) {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: GlassAppBar(
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.87),
            foregroundColor: colorScheme.surface,
            title: Text('Foto Ruangan',
                style: TextStyle(color: colorScheme.surface)),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: colorScheme.surface.withValues(alpha: 0.54),
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
