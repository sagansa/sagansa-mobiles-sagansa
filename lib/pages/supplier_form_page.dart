import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';
import '../services/image_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_container.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_form_field.dart';
import '../widgets/section_card.dart';

class SupplierFormPage extends StatelessWidget {
  final SupplierModel? supplier;

  const SupplierFormPage({super.key, this.supplier});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SupplierProvider(editingSupplier: supplier)..loadLookups(),
      child: _SupplierFormView(isEditing: supplier != null),
    );
  }
}

class _SupplierFormView extends StatelessWidget {
  final bool isEditing;
  final _formKey = GlobalKey<FormState>();

  _SupplierFormView({required this.isEditing});

  Future<void> _submit(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    if (!_formKey.currentState!.validate()) return;
    if (provider.form.selectedProvince == null ||
        provider.form.selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provinsi dan Kota harus diisi.')),
      );
      return;
    }

    final data = provider.buildPayload();
    try {
      if (isEditing) {
        await provider.submitUpdate(provider.editingSupplier!.id, data,
            image: provider.form.pickedImage);
      } else {
        await provider.submitCreate(data, image: provider.form.pickedImage);
      }
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        isEditing
            ? 'Supplier berhasil diperbarui.'
            : 'Supplier berhasil ditambahkan.',
        background: AppColors.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _validateQris(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    try {
      await provider.validateQris();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'QRIS tidak valid: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }

  /// Decode QRIS dari gambar galeri — gambar dipakai sesaat saja untuk
  /// membaca payload, tidak diunggah/disimpan (paritas `readQrisPayload`
  /// di apps/ops).
  Future<void> _decodeQrisFromGallery(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final scanner = MobileScannerController();
      try {
        final capture = await scanner.analyzeImage(picked.path);
        final raw =
            capture?.barcodes.firstOrNull?.rawValue?.trim();
        if (raw == null || raw.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'QR tidak terbaca. Coba gambar QRIS yang lebih jelas.')),
          );
          return;
        }
        provider.qrisController.text = raw;
        if (!context.mounted) return;
        await _validateQris(context);
      } finally {
        scanner.dispose();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Gagal membaca gambar: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<SupplierProvider>();
    final form = provider.form;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Supplier' : 'Tambah Supplier'),
        actions: [
          if (!form.isSaving)
            TextButton(
              onPressed: () => _submit(context),
              child: Text(
                'Simpan',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: form.isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.paddingMD,
                children: [
                  // Image picker
                  _buildImagePicker(context, colorScheme),
                  AppSpacing.gapVerticalMD,

                  SectionCard(
                    title: 'Informasi Dasar',
                    icon: Icons.store_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: provider.nameController,
                          label: 'Nama Supplier *',
                          hint: 'Nama supplier',
                          icon: Icons.store_rounded,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Nama wajib diisi'
                              : null,
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildTextField(
                          controller: provider.noTelpController,
                          label: 'No. Telepon',
                          hint: '08xxxxxxxx',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalMD,

                  SectionCard(
                    title: 'Rekening Bank',
                    icon: Icons.account_balance_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDropdown<BankModel>(
                          label: 'Bank',
                          hint: 'Pilih bank (opsional)',
                          icon: Icons.account_balance_rounded,
                          value: form.selectedBank,
                          items: form.banks,
                          itemLabel: (b) => b.name,
                          onChanged: (val) => context
                              .read<SupplierProvider>()
                              .setSelectedBank(val),
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildTextField(
                          controller: provider.bankAccountNameController,
                          label: 'Nama Pemilik Rekening',
                          hint: 'Nama sesuai rekening bank',
                          icon: Icons.person_rounded,
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildTextField(
                          controller: provider.bankAccountNoController,
                          label: 'Nomor Rekening',
                          hint: 'Nomor rekening',
                          icon: Icons.credit_card_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalMD,

                  SectionCard(
                    title: 'QRIS',
                    icon: Icons.qr_code_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ModernTextFormField(
                                controller: provider.qrisController,
                                labelText: 'QRIS Payload',
                                hintText: 'Tempel hasil scan QRIS supplier',
                                prefixIcon:
                                    const Icon(Icons.qr_code_rounded, size: 20),
                                maxLines: 2,
                                onChanged: (_) => _validateQris(context),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              tooltip: 'Scan QRIS',
                              onPressed: () async {
                                final scanned = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const _QrisScannerPage(),
                                  ),
                                );
                                if (scanned != null && context.mounted) {
                                  provider.qrisController.text = scanned;
                                  await _validateQris(context);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library_outlined),
                              tooltip: 'Pilih gambar QRIS dari galeri',
                              onPressed: () =>
                                  _decodeQrisFromGallery(context),
                            ),
                          ],
                        ),
                        if (form.qrisValidating)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Row(
                              children: [
                                const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                AppSpacing.gapHorizontalSM,
                                Text('Memvalidasi QRIS...',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        if (form.qrisMerchantName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Merchant: ${form.qrisMerchantName}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (form.qrisNmid != null)
                                  Text(
                                    'NMID: ${form.qrisNmid}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalMD,

                  SectionCard(
                    title: 'Alamat',
                    icon: Icons.home_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: provider.addressController,
                          label: 'Alamat Lengkap *',
                          hint: 'Jalan, nomor, RT/RW, dll.',
                          icon: Icons.home_rounded,
                          maxLines: 3,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Alamat wajib diisi'
                              : null,
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildDropdown<ProvinceModel>(
                          label: 'Provinsi *',
                          hint: 'Pilih provinsi',
                          icon: Icons.flag_rounded,
                          value: form.selectedProvince,
                          items: form.provinces,
                          itemLabel: (p) => p.name,
                          onChanged: (val) async {
                            await context
                                .read<SupplierProvider>()
                                .setSelectedProvince(val);
                          },
                          isRequired: true,
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildDropdown<CityModel>(
                          label: 'Kota/Kabupaten *',
                          hint: form.selectedProvince == null
                              ? 'Pilih provinsi dulu'
                              : (form.isLoadingCities
                                  ? 'Memuat...'
                                  : 'Pilih kota'),
                          icon: Icons.location_on_rounded,
                          value: form.selectedCity,
                          items: form.cities,
                          itemLabel: (c) => c.name,
                          onChanged: form.selectedProvince == null
                              ? null
                              : (val) async {
                                  await context
                                      .read<SupplierProvider>()
                                      .setSelectedCity(val);
                                },
                          isRequired: true,
                          isLoading: form.isLoadingCities,
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildDropdown<DistrictModel>(
                          label: 'Kecamatan',
                          hint: form.selectedCity == null
                              ? 'Pilih kota dulu'
                              : (form.isLoadingDistricts
                                  ? 'Memuat...'
                                  : 'Pilih kecamatan'),
                          icon: Icons.map_rounded,
                          value: form.selectedDistrict,
                          items: form.districts,
                          itemLabel: (d) => d.name,
                          onChanged: form.selectedCity == null
                              ? null
                              : (val) async {
                                  await context
                                      .read<SupplierProvider>()
                                      .setSelectedDistrict(val);
                                },
                          isLoading: form.isLoadingDistricts,
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildDropdown<SubdistrictModel>(
                          label: 'Kelurahan',
                          hint: form.selectedDistrict == null
                              ? 'Pilih kecamatan dulu'
                              : (form.isLoadingSubdistricts
                                  ? 'Memuat...'
                                  : 'Pilih kelurahan'),
                          icon: Icons.location_city_rounded,
                          value: form.selectedSubdistrict,
                          items: form.subdistricts,
                          itemLabel: (s) => s.name,
                          onChanged: form.selectedDistrict == null
                              ? null
                              : (val) async {
                                  await context
                                      .read<SupplierProvider>()
                                      .setSelectedSubdistrict(val);
                                },
                          isLoading: form.isLoadingSubdistricts,
                        ),
                        AppSpacing.gapVerticalSM,
                        _buildDropdown<PostalCodeModel>(
                          label: 'Kode Pos',
                          hint: form.selectedSubdistrict == null
                              ? 'Pilih kelurahan dulu'
                              : (form.isLoadingPostalCodes
                                  ? 'Memuat...'
                                  : 'Pilih kode pos'),
                          icon: Icons.markunread_mailbox_rounded,
                          value: form.selectedPostalCode,
                          items: form.postalCodes,
                          itemLabel: (p) => p.postalCode,
                          onChanged: form.selectedSubdistrict == null
                              ? null
                              : (val) => context
                                  .read<SupplierProvider>()
                                  .setSelectedPostalCode(val),
                          isLoading: form.isLoadingPostalCodes,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVerticalXL,
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomBar(context, form.isSaving),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isSaving) {
    return GlassContainer.bottomBar(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.lg),
      child: ModernButton(
        text: isEditing ? 'Simpan Perubahan' : 'Tambah Supplier',
        onPressed: isSaving ? null : () => _submit(context),
        isLoading: isSaving,
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    final photo = await ImageService.pickAndResizeImage(
      source: ImageSource.gallery,
    );
    if (photo != null) {
      provider.setPickedImage(photo);
    }
  }

  Widget _buildImagePicker(BuildContext context, ColorScheme colorScheme) {
    final provider = context.watch<SupplierProvider>();
    final pickedImage = provider.form.pickedImage;
    final hasImage = pickedImage != null;
    final existingImageUrl = provider.editingSupplier?.image;

    return GestureDetector(
      onTap: () => _pickImage(context),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: AppSpacing.borderRadiusLG,
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(pickedImage, fit: BoxFit.cover),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        borderRadius: AppSpacing.borderRadiusXL,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 13, color: colorScheme.surface),
                          AppSpacing.gapHorizontalXS,
                          Text('Ganti Foto',
                              style: TextStyle(
                                  color: colorScheme.surface, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : existingImageUrl != null && existingImageUrl.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        '${ApiConstants.baseUrl}/media/$existingImageUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildImagePlaceholder(colorScheme),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            borderRadius: AppSpacing.borderRadiusXL,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 13, color: colorScheme.surface),
                              AppSpacing.gapHorizontalXS,
                              Text('Ganti Foto',
                                  style: TextStyle(
                                      color: colorScheme.surface,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildImagePlaceholder(colorScheme),
      ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: colorScheme.primary,
        ),
        AppSpacing.gapVerticalSM,
        Text(
          'Tambah Foto Supplier',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.gapVerticalXS,
        Text(
          'Opsional — wajib sebelum diverifikasi Valid',
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return ModernTextFormField(
      controller: controller,
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      keyboardType: keyboardType ?? TextInputType.text,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?>? onChanged,
    bool isRequired = false,
    bool isLoading = false,
  }) {
    return isLoading
        ? Row(
            children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: AppSpacing.md),
              Text(hint,
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 14)),
            ],
          )
        : ModernDropdown<T>(
            value: value,
            labelText: label,
            hint: hint,
            isRequired: isRequired,
            prefixIcon: Icon(icon, size: 20, color: AppColors.info),
            items: items,
            getLabel: itemLabel,
            onChanged: onChanged,
            validator: isRequired
                ? (v) => v == null ? '$label wajib dipilih' : null
                : null,
          );
  }
}

/// Full-screen QRIS scanner page.
class _QrisScannerPage extends StatefulWidget {
  const _QrisScannerPage();

  @override
  State<_QrisScannerPage> createState() => _QrisScannerPageState();
}

class _QrisScannerPageState extends State<_QrisScannerPage> {
  MobileScannerController? _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      _hasScanned = true;
      Navigator.pop(context, barcode.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QRIS Supplier'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller!,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                ),
                onPressed: () => _controller!.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.surface, width: 2),
                borderRadius: AppSpacing.borderRadiusLG,
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke QRIS supplier',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.surface.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
