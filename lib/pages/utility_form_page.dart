import 'package:flutter/material.dart';

import '../models/utility_model.dart';
import '../services/utility_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_form_field.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/section_card.dart';

/// Form create/edit Utility (khusus admin/super_admin).
/// Edit bila [utility] diberikan; create bila null.
class UtilityFormPage extends StatefulWidget {
  final UtilityModel? utility;

  const UtilityFormPage({super.key, this.utility});

  @override
  State<UtilityFormPage> createState() => _UtilityFormPageState();
}

class _UtilityFormPageState extends State<UtilityFormPage> {
  final UtilityService _service = UtilityService();
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingLookups = true;
  String? _errorMessage;

  // Lookup data
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _providers = [];

  // Selections
  Map<String, dynamic>? _store;
  Map<String, dynamic>? _unit;
  Map<String, dynamic>? _provider;
  int? _prePost = 1; // Default to Prabayar
  int? _category = 1; // Default to Listrik
  int _status = 1;

  bool get _isEditing => widget.utility != null;

  @override
  void initState() {
    super.initState();
    final u = widget.utility;
    if (u != null) {
      _numberController.text = u.number ?? '';
      _nameController.text = u.name ?? '';
      _prePost = u.prePost;
      _category = u.category;
      _status = u.status ?? 1;
    }
    _loadLookups();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final lookups = await _service.getLookups();
      if (!mounted) return;
      setState(() {
        _stores = lookups['stores'] ?? [];
        _units = lookups['units'] ?? [];
        _providers = lookups['utility_providers'] ?? [];

        // Prefill relasi saat edit (match by id).
        final u = widget.utility;
        if (u != null) {
          _store = _stores
              .where((s) => s['id'].toString() == u.storeId.toString())
              .firstOrNull;
          _unit = u.unit != null
              ? _units
                  .where((n) =>
                      n['unit'].toString() == u.unit.toString())
                  .firstOrNull
              : null;
          _provider = _providers
              .where((p) =>
                  p['id'].toString() == u.utilityProviderId.toString())
              .firstOrNull;
        }
        _isLoadingLookups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoadingLookups = false;
      });
    }
  }

  int _id(Map<String, dynamic> m) =>
      m['id'] is int ? m['id'] as int : int.parse(m['id'].toString());

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis utility.')),
      );
      return;
    }
    if (_store == null || _unit == null || _provider == null || _prePost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua field yang wajib diisi.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'number': _numberController.text.trim(),
        'name': _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        'store_id': _id(_store!),
        'unit_id': _id(_unit!),
        'utility_provider_id': _id(_provider!),
        'pre_post': _prePost,
        'category': _category,
        'status': _status,
      };
      if (_isEditing) {
        await _service.updateUtility(widget.utility!.id, payload);
      } else {
        await _service.createUtility(payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  Widget _buildCategorySelector(ColorScheme colorScheme, TextTheme textTheme) {
    final categories = [
      (id: 1, label: 'Listrik', icon: Icons.bolt_rounded, color: AppColors.warning),
      (id: 2, label: 'Air', icon: Icons.water_drop_rounded, color: AppColors.info),
      (id: 3, label: 'Internet', icon: Icons.wifi_rounded, color: Colors.indigo),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'Jenis Utility',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Row(
          children: categories.map((cat) {
            final isSelected = _category == cat.id;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: isSelected
                      ? cat.color.withValues(alpha: 0.14)
                      : colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusMD,
                    side: BorderSide(
                      color: isSelected
                          ? cat.color
                          : colorScheme.outlineVariant.withValues(alpha: 0.4),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _category = cat.id),
                    borderRadius: AppSpacing.borderRadiusMD,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            color: isSelected
                                ? cat.color
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            cat.label,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? cat.color
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // extendBody tetap false: jika true, konten bawah form tertutup bar aksi
      // (bar sudah meng-handle system inset sendiri lewat SafeBottomBar).
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(_isEditing ? 'Edit Utility' : 'Tambah Utility'),
      ),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                              _isLoadingLookups = true;
                            });
                            _loadLookups();
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: AppSpacing.paddingMD.copyWith(
                      top: AppBarInsets.top(context) + AppSpacing.xs,
                      bottom: 76 + context.systemBottomInset,
                    ),
                    children: [
                      _buildCategorySelector(colorScheme, textTheme),
                      const SizedBox(height: 10),
                      SectionCard(
                        title: 'Informasi Akun',
                        icon: Icons.tag_rounded,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ModernTextFormField(
                              labelText: 'Nomor Utility (Wajib)',
                              hintText: 'Contoh: 53123456789',
                              controller: _numberController,
                              prefixIcon:
                                  const Icon(Icons.numbers_rounded, size: 18),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Nomor wajib diisi'
                                      : null,
                            ),
                            const SizedBox(height: 8),
                            ModernTextFormField(
                              labelText: 'Nama Rekening / Catatan (opsional)',
                              hintText: 'Contoh: PLN Gudang Utama',
                              controller: _nameController,
                              prefixIcon:
                                  const Icon(Icons.badge_outlined, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SectionCard(
                        title: 'Relasi & Lokasi',
                        icon: Icons.hub_outlined,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ModernDropdown<Map<String, dynamic>>(
                              labelText: 'Toko',
                              hint: 'Pilih toko...',
                              isRequired: true,
                              prefixIcon: const Icon(Icons.storefront_rounded,
                                  size: 18),
                              value: _store,
                              items: _stores,
                              getLabel: (s) =>
                                  s['nickname']?.toString() ??
                                  'Toko #${s['id']}',
                              onChanged: (v) => setState(() => _store = v),
                            ),
                            const SizedBox(height: 8),
                            ModernDropdown<Map<String, dynamic>>(
                              labelText: 'Provider',
                              hint: 'Pilih provider...',
                              isRequired: true,
                              prefixIcon:
                                  const Icon(Icons.cable_rounded, size: 18),
                              value: _provider,
                              items: _providers,
                              getLabel: (p) =>
                                  p['name']?.toString() ?? 'Provider #${p['id']}',
                              onChanged: (v) => setState(() => _provider = v),
                            ),
                            const SizedBox(height: 8),
                            ModernDropdown<Map<String, dynamic>>(
                              labelText: 'Satuan',
                              hint: 'Pilih satuan...',
                              isRequired: true,
                              prefixIcon: const Icon(Icons.straighten_rounded,
                                  size: 18),
                              value: _unit,
                              items: _units,
                              getLabel: (n) =>
                                  n['unit']?.toString() ?? 'Satuan #${n['id']}',
                              onChanged: (v) => setState(() => _unit = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SectionCard(
                        title: 'Metode & Status',
                        icon: Icons.tune_rounded,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Sistem Pembayaran', context),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<int>(
                                segments: const [
                                  ButtonSegment(
                                    value: 1,
                                    label: Text('Prabayar'),
                                    icon: Icon(Icons.flash_on_rounded, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 2,
                                    label: Text('Pascabayar'),
                                    icon: Icon(Icons.receipt_long_rounded, size: 16),
                                  ),
                                ],
                                selected: _prePost == null ? {1} : {_prePost!},
                                showSelectedIcon: false,
                                onSelectionChanged: (set) {
                                  if (set.isNotEmpty) {
                                    setState(() => _prePost = set.first);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildFieldLabel('Status', context),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<int>(
                                segments: const [
                                  ButtonSegment(
                                    value: 1,
                                    label: Text('Aktif'),
                                    icon: Icon(Icons.check_circle_outline_rounded, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 2,
                                    label: Text('Nonaktif'),
                                    icon: Icon(Icons.pause_circle_outline_rounded, size: 16),
                                  ),
                                ],
                                selected: {_status},
                                showSelectedIcon: false,
                                onSelectionChanged: (set) {
                                  if (set.isNotEmpty) {
                                    setState(() => _status = set.first);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeBottomBar(
        child: ModernButton(
          text: _isEditing ? 'Simpan Perubahan' : 'Buat Utility',
          onPressed: _isSaving ? null : _submit,
          isLoading: _isSaving,
          fullWidth: true,
        ),
      ),
    );
  }
}
