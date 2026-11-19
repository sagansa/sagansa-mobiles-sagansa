import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:provider/provider.dart';


import '../models/asset_category_model.dart';
import '../models/store_model.dart';
import '../providers/asset_provider.dart';
import '../services/image_service.dart';
import '../services/store_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_dropdown.dart';

/// Form catat aset manual (off-catalog). Penambahan aset dari produk
/// (recommended) dilakukan via AssetFromProductPage — halaman ini hanya untuk
/// aset yang tidak ada di katalog produk.
class AssetFormPage extends StatefulWidget {
  const AssetFormPage({super.key, this.assetId, this.initialStoreId});

  final int? assetId;
  final int? initialStoreId;

  @override
  State<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends State<AssetFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  List<AssetCategoryModel> _categories = [];
  List<StoreModel> _stores = [];

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int? _selectedCategoryId;
  int? _selectedStoreId;
  int _selectedCondition = 1; // default: baik
  int _selectedStatus = 1; // default: aktif
  File? _photo;

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.initialStoreId;
    _loadLookups();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final storeService = StoreService();
      final results = await Future.wait<dynamic>([
        context.read<AssetProvider>().loadCategories(),
        storeService.getStores(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<AssetCategoryModel>;
        _stores = results[1] as List<StoreModel>;
        if (_categories.isNotEmpty) _selectedCategoryId = _categories.first.id;
        if (_selectedStoreId == null && _stores.isNotEmpty) {
          _selectedStoreId = _stores.first.id;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await ImageService.pickAndResizeImage(
      source: ImageSource.camera,
    );
    if (photo != null && mounted) setState(() => _photo = photo);
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showError('Pilih kategori aset terlebih dahulu.');
      return;
    }
    if (_selectedStoreId == null) {
      _showError('Pilih toko terlebih dahulu.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<AssetProvider>().saveAsset(
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        assetCategoryId: _selectedCategoryId!,
        storeId: _selectedStoreId!,
        condition: _selectedCondition,
        status: _selectedStatus,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        photo: _photo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aset berhasil disimpan.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        title: Text(widget.assetId == null ? 'Catat Aset (Manual)' : 'Edit Aset'),

      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              bottom: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: AppSpacing.screenPadding.copyWith(
                    top: AppBarInsets.top(context),
                  ),
                  children: [
                    // Banner info: utamakan product-driven.
                    Container(
                      padding: AppSpacing.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha:0.1),
                        borderRadius: AppSpacing.borderRadiusSM,
                        border: Border.all(
                            color: AppColors.info.withValues(alpha:0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.info, size: 18),
                          AppSpacing.gapHorizontalSM,
                          Expanded(
                            child: Text(
                              'Form ini untuk aset di luar katalog produk. '
                              'Untuk aset standar, gunakan "Tambah dari Produk" '
                              'agar konsisten antar toko.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapVerticalMD,
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
                            borderRadius: AppSpacing.borderRadiusLG,
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: _photo != null
                              ? ClipRRect(
                            borderRadius: AppSpacing.borderRadiusLG,
                                  child: Image.file(_photo!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: colorScheme.primary, size: 32),
                                    AppSpacing.gapVerticalXS,
                                    Text('Tambah Foto',
                                        style: theme.textTheme.bodySmall),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    AppSpacing.gapVerticalMD,
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Aset *',
                        hintText: 'mis. AC Split Ruang Server',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    TextFormField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kode Aset',
                        hintText: 'Kosongkan untuk auto-generate (mis. A-0012)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    ModernDropdown<int>(
                      value: _selectedCategoryId,
                      labelText: 'Kategori',
                      hint: 'Pilih kategori...',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.category_outlined, size: 20),
                      items: _categories.map((c) => c.id).toList(),
                      getLabel: (v) {
                        final c = _categories.firstWhere((e) => e.id == v, orElse: () => AssetCategoryModel(id: 0, name: '', frequencyDays: 30));
                        return '${c.name} (${c.frequencyLabel})';
                      },
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    ModernDropdown<int>(
                      value: _selectedStoreId,
                      labelText: 'Toko',
                      hint: 'Pilih toko...',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.storefront, size: 20),
                      items: _stores.map((s) => s.id).toList(),
                      getLabel: (v) {
                        final s = _stores.firstWhere((e) => e.id == v, orElse: () => StoreModel(id: 0, nickname: '', latitude: 0, longitude: 0));
                        return s.nickname.isNotEmpty ? s.nickname : 'Store #${s.id}';
                      },
                      getSubtitle: (v) {
                        return '';
                      },
                      onChanged: (v) => setState(() => _selectedStoreId = v),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    ModernDropdown<int>(
                      value: _selectedCondition,
                      labelText: 'Kondisi',
                      hint: 'Pilih kondisi...',
                      items: const [1, 2, 3, 4],
                      getLabel: (v) {
                        switch (v) {
                          case 1: return 'Baik';
                          case 2: return 'Rusak Ringan';
                          case 3: return 'Rusak Berat';
                          case 4: return 'Hilang';
                          default: return 'Baik';
                        }
                      },
                      onChanged: (v) => setState(() => _selectedCondition = v ?? 1),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    ModernDropdown<int>(
                      value: _selectedStatus,
                      labelText: 'Status',
                      hint: 'Pilih status...',
                      items: const [1, 2, 3],
                      getLabel: (v) {
                        switch (v) {
                          case 1: return 'Aktif';
                          case 2: return 'Dipelihara';
                          case 3: return 'Non-Aktif';
                          default: return 'Aktif';
                        }
                      },
                      onChanged: (v) => setState(() => _selectedStatus = v ?? 1),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                      ),
                      maxLines: 3,
                    ),
                    AppSpacing.gapVerticalLG,
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Aset'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
