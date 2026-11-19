import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../models/utility_bill_model.dart';
import '../services/image_service.dart';
import '../services/image_upload_service.dart';
import '../services/utility_bill_service.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/safe_bottom_bar.dart';

class UtilityBillFormPage extends StatefulWidget {
  final UtilityBillModel? bill;

  const UtilityBillFormPage({super.key, this.bill});

  @override
  State<UtilityBillFormPage> createState() => _UtilityBillFormPageState();
}

class _UtilityBillFormPageState extends State<UtilityBillFormPage> {
  final _formKey = GlobalKey<FormState>();
  final UtilityBillService _service = UtilityBillService();

  final _amountCtrl = TextEditingController();
  final _initialCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _utilities = [];
  Map<String, dynamic>? _selectedStore;
  List<Map<String, dynamic>> _filteredUtilities = [];
  Map<String, dynamic>? _selectedUtility;

  DateTime? _selectedDate;
  File? _photoFile;
  String? _uploadedPhotoPath;

  bool _isLoadingLookups = true;
  bool _isSaving = false;

  bool get isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    _initForm();
    _loadLookups();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _initialCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  void _initForm() {
    final b = widget.bill;
    if (b != null) {
      _amountCtrl.text = FormatUtils.formatAmount(parseAmountInt(b.amount));
      _initialCtrl.text = b.initialIndicator;
      _lastCtrl.text = b.lastIndicator;
      _selectedDate = DateTime.tryParse(b.date);
      _uploadedPhotoPath = b.image;
    }
  }

  int _storeId(Map<String, dynamic> store) =>
      store['id'] is int ? store['id'] : int.parse(store['id'].toString());

  Future<void> _loadLookups() async {
    setState(() => _isLoadingLookups = true);
    try {
      final results = await Future.wait([
        _service.getStores(),
        _service.getUtilities(),
      ]);

      if (!mounted) return;

      final stores = (results[0] as List).cast<Map<String, dynamic>>();
      final utilities = (results[1] as List).cast<Map<String, dynamic>>();

      Map<String, dynamic>? resolvedStore;
      Map<String, dynamic>? resolvedUtility;

      final b = widget.bill;
      if (b != null) {
        resolvedStore = stores.where((s) => s['id'] == b.storeId).firstOrNull;
        resolvedUtility =
            utilities.where((ut) => ut['id'] == b.utilityId).firstOrNull;
      }

      setState(() {
        _stores = stores;
        _utilities = utilities;
        _selectedStore = resolvedStore;
        _selectedUtility = resolvedUtility;
      });

      if (_selectedStore != null) {
        _updateFilteredUtilities(_storeId(_selectedStore!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLookups = false);
    }
  }

  void _updateFilteredUtilities(int storeId) {
    setState(() {
      _filteredUtilities =
          _utilities.where((u) => u['store_id'] == storeId).toList();
    });
  }

  void _onStoreChanged(Map<String, dynamic>? store) {
    setState(() {
      _selectedStore = store;
      _selectedUtility = null;
    });
    if (store != null) {
      _updateFilteredUtilities(_storeId(store));
    } else {
      setState(() => _filteredUtilities = []);
    }
  }

  String? get _selectedUnit {
    if (_selectedUtility != null) {
      return _selectedUtility!['unit']?.toString();
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await ImageService.pickAndResizeImage(
        source: ImageSource.camera,
      );
      if (photo == null) return;

      setState(() {
        _photoFile = photo;
        _uploadedPhotoPath = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoFile = null;
      _uploadedPhotoPath = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUtility == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utility wajib dipilih.')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal wajib diisi.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imagePath = _uploadedPhotoPath;
      if (_photoFile != null) {
        imagePath = await ImageUploadService.upload(
          _photoFile!,
          directory: 'images/UtilityBill',
        );
        if (imagePath == null) {
          if (!mounted) return;
          showErrorSnackBar(context, 'Gagal mengunggah foto tagihan.');
          return;
        }
      }

      final data = <String, dynamic>{
        'utility_id': _selectedUtility!['id'],
        'date':
            '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
        'amount': parseAmountInt(_amountCtrl.text).toString(),
        'initial_indicator': _initialCtrl.text.trim(),
        'last_indicator': _lastCtrl.text.trim(),
        if (imagePath != null) 'image': imagePath,
      };

      if (isEditing) {
        await _service.updateUtilityBill(widget.bill!.id, data);
      } else {
        await _service.createUtilityBill(data);
      }

      if (!mounted) return;
      showSuccessSnackBar(
        context,
        isEditing
            ? 'Tagihan utility berhasil diperbarui.'
            : 'Tagihan utility berhasil ditambahkan.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // extendBody tetap false: jika true, konten bawah form tertutup bar aksi
      // (bar sudah meng-handle system inset sendiri lewat SafeBottomBar).
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title:
            Text(isEditing ? 'Edit Tagihan Utility' : 'Tambah Tagihan Utility'),
      ),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppBarInsets.top(context) + AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl * 2,
                ),
                children: [
                  // Section 1: Toko & Utility
                  FormSectionCard(
                    title: 'Toko & Utility',
                    subtitle: 'Pilih cabang dan jenis layanan utility',
                    icon: Icons.storefront_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ModernDropdown<Map<String, dynamic>>(
                          value: _selectedStore,
                          labelText: 'Toko',
                          hint: 'Pilih toko...',
                          isRequired: true,
                          prefixIcon: const Icon(Icons.storefront, size: 20),
                          items: _stores,
                          getLabel: (s) =>
                              s['nickname']?.toString() ?? 'Toko #${s['id']}',
                          getSubtitle: (s) => s['address']?.toString() ?? '',
                          onChanged: (val) => _onStoreChanged(val),
                          validator: (v) =>
                              v == null ? 'Toko wajib dipilih' : null,
                        ),
                        AppSpacing.gapVerticalMD,
                        ModernDropdown<Map<String, dynamic>>(
                          value: _selectedUtility,
                          labelText: 'Utility',
                          hint: _selectedStore == null
                              ? 'Pilih toko terlebih dahulu'
                              : 'Pilih utility...',
                          isRequired: true,
                          enabled: _selectedStore != null,
                          prefixIcon:
                              const Icon(Icons.electrical_services, size: 20),
                          items: _filteredUtilities,
                          getLabel: (u) =>
                              '${u['utility_name'] ?? 'Utility #${u['id']}'}${u['unit'] != null ? ' (${u['unit']})' : ''}',
                          onChanged: (val) =>
                              setState(() => _selectedUtility = val),
                          validator: (v) =>
                              v == null ? 'Utility wajib dipilih' : null,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalMD,

                  // Section 2: Waktu & Nominal
                  FormSectionCard(
                    title: 'Waktu & Nominal',
                    subtitle: 'Tanggal tagihan dan jumlah pembayaran',
                    icon: Icons.payments_rounded,
                    child: Column(
                      children: [
                        _buildDateField(colorScheme),
                        AppSpacing.gapVerticalMD,
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: rupiahInputFormatters,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah Tagihan *',
                            prefixText: 'Rp ',
                            hintText: '0',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Jumlah tagihan wajib diisi'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalMD,

                  // Section 3: Indikator Meter
                  FormSectionCard(
                    title: 'Indikator Meter',
                    subtitle: 'Pencatatan angka meter awal dan akhir',
                    icon: Icons.speed_rounded,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _initialCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Indikator Awal *',
                              suffixText: _selectedUnit,
                              suffixStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                        AppSpacing.gapHorizontalMD,
                        Expanded(
                          child: TextFormField(
                            controller: _lastCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Indikator Akhir *',
                              suffixText: _selectedUnit,
                              suffixStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalMD,

                  // Section 4: Foto Tagihan
                  FormSectionCard(
                    title: 'Foto Tagihan',
                    subtitle: 'Lampirkan foto bukti meteran atau struk tagihan',
                    icon: Icons.camera_alt_rounded,
                    child: _buildPhotoSection(colorScheme),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildDateField(ColorScheme colorScheme) {
    final now = DateTime.now();
    return InkWell(
      onTap: () async {
        final initial = _selectedDate ?? now;
        final clamped = initial.isAfter(now) ? now : initial;
        final date = await showDatePicker(
          context: context,
          initialDate: clamped,
          firstDate: DateTime(2000),
          lastDate: now,
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      borderRadius: AppSpacing.borderRadiusSM,
      child: InputDecorator(
        isEmpty: _selectedDate == null,
        decoration: InputDecoration(
          labelText: 'Tanggal Tagihan *',
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          suffixIcon: _selectedDate != null
              ? IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _selectedDate = null),
                )
              : null,
        ),
        child: Text(
          _selectedDate == null
              ? 'Pilih tanggal...'
              : '${_selectedDate!.day.toString().padLeft(2, '0')} ${_monthName(_selectedDate!.month)} ${_selectedDate!.year}',
          style: TextStyle(
            color: _selectedDate == null
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[month - 1];
  }

  Widget _buildPhotoSection(ColorScheme colorScheme) {
    final hasImage = _photoFile != null || _uploadedPhotoPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImage) ...[
          if (_photoFile != null)
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusMD,
              child: Image.file(
                _photoFile!,
                height: 180,
                fit: BoxFit.cover,
              ),
            )
          else
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusMD,
              child: Image.network(
                ImageService.buildUrl(_uploadedPhotoPath) ?? '',
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image_rounded)),
                ),
              ),
            ),
          AppSpacing.gapVerticalSM,
        ],
        Row(
          children: [
            Expanded(
              child: hasImage
                  ? OutlinedButton.icon(
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Foto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Ambil Foto'),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeBottomBar(
      child: ModernButton(
        text: isEditing ? 'Simpan Perubahan' : 'Tambah Tagihan',
        icon: isEditing ? Icons.save_rounded : Icons.add_circle_rounded,
        onPressed: _isSaving ? null : _submit,
        isLoading: _isSaving,
        height: 52,
      ),
    );
  }
}
