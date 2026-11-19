import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../models/asset_category_model.dart';
import '../models/asset_model.dart';
import '../providers/asset_provider.dart';
import '../services/image_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';

/// Form pemeriksaan aset: checklist dinamis per kategori, foto kondisi,
/// geotag (wajib), severity, dan catatan. Submit multipart ke /asset-checks.
class AssetCheckFormPage extends StatefulWidget {
  const AssetCheckFormPage({super.key, required this.assetId});

  final int assetId;

  @override
  State<AssetCheckFormPage> createState() => _AssetCheckFormPageState();
}

class _AssetCheckFormPageState extends State<AssetCheckFormPage> {
  AssetModel? _asset;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _alreadyCheckedToday = false;
  bool _isAdmin = false; // Hanya admin yang dapat input severity.
  String? _errorMessage;

  // State checklist: label -> {value (bool), note}.
  final Map<String, _CheckEntry> _checklist = {};

  // Foto.
  final List<File> _photos = [];

  // Geotag.
  Position? _position;
  String? _geoStatus;

  // Severity & notes.
  int _severity = 1; // 1=ok default
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final provider = context.read<AssetProvider>();

      // Baca role user untuk gate severity.
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        final roles = List<String>.from(userData['roles'] ?? []);
        _isAdmin = roles.contains('admin');
      }

      final asset = await provider.loadAssetDetail(widget.assetId);
      final already = await provider.hasCheckedToday(widget.assetId);

      // Ambil kategori untuk dapat definisi checklist.
      AssetCategoryModel? category;
      final cats = await provider.loadCategories();
      category = cats.isEmpty
          ? null
          : cats.where((c) => c.id == asset.assetCategoryId).firstOrNull ??
              cats.first;

      // Inisialisasi checklist dari definisi kategori.
      _checklist.clear();
      if (category != null) {
        for (final item in category.checklistItems) {
          _checklist[item.label] = _CheckEntry(label: item.label);
        }
      }

      if (!mounted) return;
      setState(() {
        _asset = asset;
        _alreadyCheckedToday = already;
        _isLoading = false;
      });

      // Auto-capture lokasi di awal agar tidak lupa.
      _captureLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _geoStatus = 'Mengambil lokasi...');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _geoStatus = 'Layanan lokasi nonaktif.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _geoStatus = 'Izin lokasi ditolak.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _geoStatus = 'Izin lokasi permanen ditolak.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _geoStatus =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _geoStatus = 'Gagal mengambil lokasi: $e');
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 5) {
      _showError('Maksimal 5 foto.');
      return;
    }
    final photo = await ImageService.pickAndResizeImage(
      source: ImageSource.camera,
    );
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  /// Hitung severity otomatis: bila ada item not-ok → minimal ringan (2).
  void _recomputeSeverity() {
    final anyNotOk = _checklist.values.any((e) => !e.value);
    if (anyNotOk && _severity < 2) {
      setState(() => _severity = 2);
    } else if (!anyNotOk) {
      setState(() => _severity = 1);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showAppSnackBar(
      context,
      msg,
      background: Theme.of(context).colorScheme.error,
    );
  }

  Future<void> _submit() async {
    if (_position == null) {
      _showError('Geotag wajib. Tunggu hingga lokasi terambil atau tekan tombol refresh.');
      return;
    }
    if (_asset == null) return;

    setState(() => _isSubmitting = true);
    try {
      final checklistPayload = _checklist.values
          .map((e) => {'label': e.label, 'value': e.value ? 1 : 0, 'note': e.note})
          .toList();

      await context.read<AssetProvider>().submitCheck(
        assetId: widget.assetId,
        checkDate: DateTime.now().toIso8601String().substring(0, 10),
        conditionBefore: _asset!.condition,
        conditionAfter: _asset!.condition, // user dapat mengubah via severity
        severity: _severity,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        photos: _photos,
        checklist: checklistPayload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pemeriksaan berhasil disimpan.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Pemeriksaan Aset'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.sectionGap),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _asset == null
                  ? const Center(child: Text('Aset tidak ditemukan.'))
                  : _alreadyCheckedToday
                      ? Center(
                          child: Padding(
                            padding: AppSpacing.paddingLG,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: AppColors.success, size: 56),
                                const SizedBox(height: AppSpacing.sectionGap),
                                Text(
                                  'Aset ini sudah diperiksa hari ini.',
                                  style: theme.textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                AppSpacing.gapVerticalSM,
                                Text(
                                  '${_asset!.name} (${_asset!.code})',
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : SafeArea(
                          top: false,
                          bottom: false,
                          child: ListView(
                            padding: AppSpacing.screenPadding.copyWith(
                              top: AppBarInsets.top(context),
                            ),
                            children: [
                              _buildAssetHeader(theme, colorScheme),
                              const SizedBox(height: AppSpacing.sectionGap),
                              _buildChecklistSection(theme, colorScheme),
                              const SizedBox(height: AppSpacing.sectionGap),
                              if (_isAdmin) ...[
                                _buildSeveritySection(theme, colorScheme),
                                const SizedBox(height: AppSpacing.sectionGap),
                              ],
                              _buildPhotoSection(theme, colorScheme),
                              const SizedBox(height: AppSpacing.sectionGap),
                              _buildGeoSection(theme, colorScheme),
                              const SizedBox(height: AppSpacing.sectionGap),
                              TextField(
                                controller: _notesCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Catatan Kondisi',
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 3,
                              ),
                              AppSpacing.gapVerticalLG,
                              ModernButton(
                                text: _isSubmitting
                                    ? 'Menyimpan...'
                                    : 'Submit Pemeriksaan',
                                onPressed: _isSubmitting ? null : _submit,
                                isLoading: _isSubmitting,
                                icon: Icons.send_rounded,
                              ),
                            ],
                          ),
                        ),
    );
  }

  Widget _buildAssetHeader(ThemeData theme, ColorScheme cs) {
    final a = _asset!;
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            Icon(Icons.inventory_2, color: cs.primary),
            SizedBox(width: AppSpacing.rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${a.code} • ${a.conditionText} • ${a.assetCategoryName ?? '-'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistSection(ThemeData theme, ColorScheme cs) {
    if (_checklist.isEmpty) {
      return Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLG,
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: const Padding(
          padding: AppSpacing.cardPadding,
          child: Text('Kategori ini tidak memiliki checklist baku.'),
        ),
      );
    }
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checklist',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.gapVerticalSM,
            ..._checklist.values.map((e) => _ChecklistRow(
                  entry: e,
                  onChanged: () {
                    setState(() {});
                    _recomputeSeverity();
                  },
                  cs: cs,
                  theme: theme,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSeveritySection(ThemeData theme, ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Severity',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.gapVerticalSM,
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.6,
              children: [
                _severityButton(1, 'OK', AppColors.success, cs),
                _severityButton(2, 'Ringan', AppColors.info, cs),
                _severityButton(3, 'Sedang', AppColors.warning, cs),
                _severityButton(4, 'Berat', AppColors.error, cs),
              ],
            ),
            AppSpacing.gapVerticalXS,
            Text(
              'Issue otomatis dibuat bila severity ≥ Ringan.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _severityButton(int value, String label, Color color, ColorScheme cs) {
    final textTheme = Theme.of(context).textTheme;
    final selected = _severity == value;
    return Material(
      color: selected ? color : cs.surfaceContainerHighest.withValues(alpha:0.5),
      borderRadius: AppSpacing.borderRadiusSM,
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusSM,
        onTap: () => setState(() => _severity = value),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: selected ? cs.surface : cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(ThemeData theme, ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Foto Kondisi (${_photos.length}/5)',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            AppSpacing.gapVerticalXS,
            if (_photos.isEmpty)
              Text('Belum ada foto.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant))
            else
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => AppSpacing.gapHorizontalSM,
                  itemBuilder: (context, i) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: AppSpacing.borderRadiusSM,
                          child: Image.file(_photos[i],
                              width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(i),
                            child: Container(
                              padding: AppSpacing.paddingXS,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.54),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: cs.surface, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeoSection(ThemeData theme, ColorScheme cs) {
    final ok = _position != null;
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            Icon(ok ? Icons.location_on : Icons.location_searching,
                color: ok ? AppColors.success : AppColors.warning),
            SizedBox(width: AppSpacing.rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Geotag (wajib)',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    _geoStatus ?? 'Belum diambil.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _captureLocation,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh lokasi',
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckEntry {
  _CheckEntry({required this.label});
  final String label;
  bool value = true;
  String? note;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.entry,
    required this.onChanged,
    required this.cs,
    required this.theme,
  });

  final _CheckEntry entry;
  final VoidCallback onChanged;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.itemGap),
      child: Row(
        children: [
          Expanded(
            child: Text(entry.label, style: theme.textTheme.bodyMedium),
          ),
          ToggleButtons(
            isSelected: [entry.value, !entry.value],
            onPressed: (i) {
              entry.value = (i == 0);
              onChanged();
            },
            borderRadius: AppSpacing.borderRadiusSM,
            constraints: const BoxConstraints(minHeight: 32, minWidth: 56),
            selectedColor: theme.colorScheme.surface,
            fillColor: entry.value ? AppColors.success : AppColors.error,
            children: [
              Text('OK', style: theme.textTheme.labelMedium),
              Text('Not OK', style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}
