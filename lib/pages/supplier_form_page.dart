import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/supplier_model.dart';
import '../providers/auth_provider.dart';
import '../providers/supplier_provider.dart';
import '../services/image_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import '../utils/country_catalog.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_form_field.dart';

/// Form tambah/edit supplier — desain "Dua Fase": zona inti (asal,
/// identitas, lokasi) berdiri di kartu solid dan bisa disimpan sendirian;
/// pembayaran (QRIS/rekening) adalah fase kedua di kartu tonal bergaris
/// putus yang jujur dinamai "bisa dilengkapi nanti" — tombol simpan
/// menyebut keadaannya. Seksi menyesuaikan asal: domestik memakai cascade
/// wilayah Indonesia, bank lokal & QRIS; luar negeri memakai negara + kota
/// bebas, bank LN (nama + SWIFT) & valuta transaksi default.
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

class _SupplierFormView extends StatefulWidget {
  final bool isEditing;

  const _SupplierFormView({required this.isEditing});

  @override
  State<_SupplierFormView> createState() => _SupplierFormViewState();
}

class _SupplierFormViewState extends State<_SupplierFormView> {
  final _formKey = GlobalKey<FormState>();

  /// Zona pembayaran tertunda sampai dibuka; sekali dibuka menjadi seksi
  /// normal dan tidak dilipat lagi. Edit mode terbuka bila supplier
  /// sudah punya data pembayaran.
  late bool _paymentExpanded;

  Listenable? _paymentTextListen;

  @override
  void initState() {
    super.initState();
    _paymentExpanded = _initialPaymentExpanded();
  }

  bool _initialPaymentExpanded() {
    final s = context.read<SupplierProvider>().editingSupplier;
    return s != null &&
        ((s.bankAccountName ?? '').isNotEmpty ||
            (s.bankAccountNo ?? '').isNotEmpty ||
            (s.qris ?? '').isNotEmpty ||
            s.bankId != null ||
            (s.bankName ?? '').isNotEmpty ||
            (s.bankSwiftCode ?? '').isNotEmpty);
  }

  /// Isian teks pembayaran tidak memicu notifyListeners — gabungkan
  /// controller-controller itu agar label tombol simpan mengikuti ketikan.
  Listenable _paymentListen() {
    final p = context.read<SupplierProvider>();
    return _paymentTextListen ??= Listenable.merge([
      p.qrisController,
      p.bankNameController,
      p.bankSwiftController,
      p.bankAccountNameController,
      p.bankAccountNoController,
    ]);
  }

  bool _hasPayment(SupplierProvider p, SupplierFormState form) {
    bool filled(String s) => s.trim().isNotEmpty;
    if (form.isForeign) {
      return filled(p.bankNameController.text) ||
          filled(p.bankSwiftController.text) ||
          filled(p.bankAccountNameController.text) ||
          filled(p.bankAccountNoController.text);
    }
    return filled(p.qrisController.text) ||
        filled(p.bankAccountNameController.text) ||
        filled(p.bankAccountNoController.text) ||
        form.selectedBank != null;
  }

  Future<void> _submit(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    if (!_formKey.currentState!.validate()) return;
    final form = provider.form;
    if (form.isForeign) {
      if (form.selectedCountry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Negara supplier harus dipilih.')),
        );
        return;
      }
    } else if (form.selectedProvince == null || form.selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provinsi dan Kota harus diisi.')),
      );
      return;
    }

    final hasPayment = _hasPayment(provider, form);
    final data = provider.buildPayload();
    try {
      if (widget.isEditing) {
        await provider.submitUpdate(provider.editingSupplier!.id, data,
            image: provider.form.pickedImage);
      } else {
        await provider.submitCreate(data, image: provider.form.pickedImage);
      }
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        widget.isEditing
            ? 'Supplier berhasil diperbarui.'
            : (hasPayment
                ? 'Supplier berhasil ditambahkan.'
                : 'Supplier disimpan — pembayaran bisa dilengkapi nanti.'),
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
        final raw = capture?.barcodes.firstOrNull?.rawValue?.trim();
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

  /// Scan langsung dari kartu pembayaran tertunda: zona mekar terbuka dan
  /// hasil scan langsung tervalidasi — jalur tercepat di lokasi supplier.
  Future<void> _scanQrisAndExpand(BuildContext context) async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrisScannerPage()),
    );
    if (scanned == null || !context.mounted) return;
    setState(() => _paymentExpanded = true);
    context.read<SupplierProvider>().qrisController.text = scanned;
    await _validateQris(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<SupplierProvider>();
    final form = provider.form;
    // Supplier luar negeri hanya boleh dibuat admin (gerbang backend 403);
    // non-admin tidak diberi pilihan asalnya sama sekali.
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return AppPageScaffold(
      titleText: widget.isEditing ? 'Edit Supplier' : 'Tambah Supplier',
      isLoading: form.isLoadingLookups,
      errorMessage: form.lookupErrorMessage,
      onRetry: () => provider.loadLookups(),
      bodyPadding: EdgeInsets.zero,
      body: Builder(
        // Konteks dalam body Scaffold: clearance atas (app bar kaca) +
        // bawah (bar aksi simpan, extendBody) dari MediaQuery.
        builder: (bodyContext) => Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screenPadding.copyWith(
              top: AppBarInsets.top(bodyContext),
              bottom:
                  MediaQuery.paddingOf(bodyContext).bottom + AppSpacing.md,
            ),
            children: [
              if (isAdmin)
                _buildOriginPivot(context, form, theme)
              else
                _buildDomesticOnlyNote(theme),
              const SizedBox(height: AppSpacing.sectionGap),
              _buildIdentitySection(context, provider, form, theme),
              const SizedBox(height: AppSpacing.sectionGap),
              _buildLocationSection(context, provider, form, theme),
              const SizedBox(height: AppSpacing.sectionGap),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _paymentExpanded
                    ? _buildPaymentSection(context, provider, form, theme)
                    : _buildDeferredPaymentCard(context, form, theme),
              ),
              AppSpacing.gapVerticalXL,
            ],
          ),
        ),
      ),
      bottomAction: _buildBottomBar(context, provider, form),
    );
  }

  /// Pilihan asal supplier — pivot pertama yang mengubah seluruh isi
  /// zona di bawahnya; berdiri sendiri di atas kartu-kartu inti.
  Widget _buildOriginPivot(
    BuildContext context,
    SupplierFormState form,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asal Supplier',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapVerticalXS,
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Domestik'),
                icon: Icon(Icons.flag_outlined, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('Luar Negeri'),
                icon: Icon(Icons.public_outlined, size: 18),
              ),
            ],
            selected: {form.isForeign},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                context.read<SupplierProvider>().setForeign(selection.first),
          ),
        ),
        AppSpacing.gapVerticalXS,
        Text(
          form.isForeign
              ? 'Negara & kota bebas, bank luar negeri (SWIFT), valuta transaksi.'
              : 'Wilayah Indonesia, bank lokal, dan QRIS.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDomesticOnlyNote(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Supplier luar negeri hanya dapat dibuat oleh admin.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentitySection(
    BuildContext context,
    SupplierProvider provider,
    SupplierFormState form,
    ThemeData theme,
  ) {
    final dial = form.selectedCountry?.dialCode;
    return FormSectionCard(
      title: 'Identitas',
      subtitle: 'Foto, nama & kontak',
      icon: Icons.store_rounded,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhotoTile(context, provider, theme),
            AppSpacing.gapHorizontalMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ModernTextFormField(
                    controller: provider.nameController,
                    labelText: 'Nama Supplier',
                    isRequired: true,
                    hintText: 'Nama supplier',
                    prefixIcon: const Icon(Icons.store_rounded, size: 20),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  AppSpacing.gapVerticalSM,
                  ModernTextFormField(
                    controller: provider.noTelpController,
                    labelText: 'No. Telepon',
                    hintText: form.isForeign
                        ? '${dial ?? '+'}… (dengan kode negara)'
                        : '08xxxxxxxx',
                    prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          'Foto opsional — wajib sebelum diverifikasi Valid.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
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

  /// Foto sebagai ubin persegi di kiri nama — pasangan seperti kartu
  /// daftar/detail; ketuk untuk memilih, badge edit saat terisi.
  Widget _buildPhotoTile(
    BuildContext context,
    SupplierProvider provider,
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    final picked = provider.form.pickedImage;
    final existingUrl = provider.editingSupplier?.image;
    final hasNetworkImage = existingUrl != null && existingUrl.isNotEmpty;

    Widget content;
    if (picked != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [Image.file(picked, fit: BoxFit.cover), _photoBadge(cs)],
      );
    } else if (hasNetworkImage) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            '${ApiConstants.baseUrl}/media/$existingUrl',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _photoPlaceholder(theme),
          ),
          _photoBadge(cs),
        ],
      );
    } else {
      content = _photoPlaceholder(theme);
    }

    return GestureDetector(
      onTap: () => _pickImage(context),
      child: Container(
        width: 100,
        height: 100,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: AppSpacing.borderRadiusMD,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _photoBadge(ColorScheme cs) => Positioned(
        bottom: 6,
        right: 6,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.edit_rounded, size: 13, color: cs.surface),
        ),
      );

  Widget _photoPlaceholder(ThemeData theme) {
    final cs = theme.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 26, color: cs.primary),
        AppSpacing.gapVerticalXS,
        Text(
          'Foto',
          style: theme.textTheme.labelSmall?.copyWith(color: cs.primary),
        ),
      ],
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    SupplierProvider provider,
    SupplierFormState form,
    ThemeData theme,
  ) {
    if (form.isForeign) {
      return FormSectionCard(
        title: 'Lokasi',
        subtitle: 'Negara, kota & valuta transaksi',
        icon: Icons.public_outlined,
        children: [
          _buildDropdown<Country>(
            label: 'Negara',
            hint: 'Pilih negara asal',
            icon: Icons.public_rounded,
            value: form.selectedCountry,
            items: CountryCatalog.foreign,
            itemLabel: (c) => c.name,
            itemSubtitle: (c) => '${c.code} • ${c.currency} • ${c.dialCode}',
            onChanged: (val) =>
                context.read<SupplierProvider>().setCountry(val),
            isRequired: true,
          ),
          _buildDropdown<String>(
            label: 'Valuta Transaksi',
            hint: 'Valuta penagihan supplier',
            icon: Icons.currency_exchange_rounded,
            value: form.currency,
            items: CurrencyCatalog.withCode(form.currency),
            itemLabel: (c) => c,
            onChanged: (val) =>
                context.read<SupplierProvider>().setCurrency(val),
          ),
          ModernTextFormField(
            controller: provider.cityNameController,
            labelText: 'Kota',
            isRequired: true,
            hintText: 'mis. Ho Chi Minh City',
            prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Kota wajib diisi' : null,
          ),
          ModernTextFormField(
            controller: provider.addressController,
            labelText: 'Alamat Lengkap',
            isRequired: true,
            hintText: 'Jalan, nomor, distrik, kode pos',
            prefixIcon: const Icon(Icons.home_rounded, size: 20),
            maxLines: 3,
            validator: (v) =>
                v == null || v.isEmpty ? 'Alamat wajib diisi' : null,
          ),
        ],
      );
    }

    return FormSectionCard(
      title: 'Lokasi',
      subtitle: 'Alamat & wilayah Indonesia',
      icon: Icons.location_on_outlined,
      children: [
        ModernTextFormField(
          controller: provider.addressController,
          labelText: 'Alamat Lengkap',
          isRequired: true,
          hintText: 'Jalan, nomor, RT/RW, dll.',
          prefixIcon: const Icon(Icons.home_rounded, size: 20),
          maxLines: 3,
          validator: (v) => v == null || v.isEmpty ? 'Alamat wajib diisi' : null,
        ),
        ..._buildRegionCascade(context, form),
      ],
    );
  }

  List<Widget> _buildRegionCascade(
    BuildContext context,
    SupplierFormState form,
  ) {
    return [
      _buildDropdown<ProvinceModel>(
        label: 'Provinsi',
        hint: 'Pilih provinsi',
        icon: Icons.flag_rounded,
        value: form.selectedProvince,
        items: form.provinces,
        itemLabel: (p) => p.name,
        onChanged: (val) async {
          await context.read<SupplierProvider>().setSelectedProvince(val);
        },
        isRequired: true,
      ),
      _buildDropdown<CityModel>(
        label: 'Kota/Kabupaten',
        hint: form.selectedProvince == null
            ? 'Pilih provinsi dulu'
            : (form.isLoadingCities ? 'Memuat...' : 'Pilih kota'),
        icon: Icons.location_on_rounded,
        value: form.selectedCity,
        items: form.cities,
        itemLabel: (c) => c.name,
        onChanged: form.selectedProvince == null
            ? null
            : (val) async {
                await context.read<SupplierProvider>().setSelectedCity(val);
              },
        isRequired: true,
        isLoading: form.isLoadingCities,
      ),
      _buildDropdown<DistrictModel>(
        label: 'Kecamatan',
        hint: form.selectedCity == null
            ? 'Pilih kota dulu'
            : (form.isLoadingDistricts ? 'Memuat...' : 'Pilih kecamatan'),
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
      _buildDropdown<SubdistrictModel>(
        label: 'Kelurahan',
        hint: form.selectedDistrict == null
            ? 'Pilih kecamatan dulu'
            : (form.isLoadingSubdistricts ? 'Memuat...' : 'Pilih kelurahan'),
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
      _buildDropdown<PostalCodeModel>(
        label: 'Kode Pos',
        hint: form.selectedSubdistrict == null
            ? 'Pilih kelurahan dulu'
            : (form.isLoadingPostalCodes ? 'Memuat...' : 'Pilih kode pos'),
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
    ];
  }

  /// Zona pembayaran tertunda: kartu tonal bergaris putus — bukan seksi
  /// keempat yang sama beratnya. Seluruh kartu bisa diketuk; aksi tercepat
  /// (Scan QRIS) tersedia langsung dari keadaan tertutup.
  Widget _buildDeferredPaymentCard(
    BuildContext context,
    SupplierFormState form,
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: AppSpacing.borderRadiusLG,
      onTap: () => setState(() => _paymentExpanded = true),
      child: _DashedCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  AppSpacing.gapHorizontalSM,
                  Text(
                    'Pembayaran',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVerticalXS,
              Text(
                'Belum diisi — bisa dilengkapi nanti saat edit.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              AppSpacing.gapVerticalMD,
              Row(
                children: [
                  if (!form.isForeign) ...[
                    Expanded(
                      child: ModernButton(
                        variant: ModernButtonVariant.outlined,
                        text: 'Scan QRIS',
                        icon: Icons.qr_code_scanner_rounded,
                        height: 44,
                        onPressed: () => _scanQrisAndExpand(context),
                      ),
                    ),
                    AppSpacing.gapHorizontalSM,
                  ],
                  Expanded(
                    child: ModernButton(
                      variant: ModernButtonVariant.outlined,
                      text: form.isForeign ? 'Isi Rekening Bank' : 'Isi Manual',
                      icon: form.isForeign
                          ? Icons.account_balance_outlined
                          : Icons.edit_outlined,
                      height: 44,
                      onPressed: () =>
                          setState(() => _paymentExpanded = true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Zona pembayaran terbuka — kartu solid seperti zona inti; QRIS
  /// menempati posisi teratas untuk domestik (ritual lapangan: stiker
  /// QRIS ada di lokasi), rekening bank menyusul.
  Widget _buildPaymentSection(
    BuildContext context,
    SupplierProvider provider,
    SupplierFormState form,
    ThemeData theme,
  ) {
    if (form.isForeign) {
      return FormSectionCard(
        title: 'Pembayaran',
        subtitle: 'Rekening bank luar negeri — opsional',
        icon: Icons.payments_outlined,
        children: [
          ModernTextFormField(
            controller: provider.bankNameController,
            labelText: 'Nama Bank',
            hintText: 'mis. Vietcombank, HSBC',
            prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
            textCapitalization: TextCapitalization.words,
          ),
          ModernTextFormField(
            controller: provider.bankSwiftController,
            labelText: 'Kode SWIFT / BIC',
            hintText: '8–11 karakter, mis. BFTVVNVX',
            prefixIcon: const Icon(Icons.tag_rounded, size: 20),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(11),
            ],
          ),
          ModernTextFormField(
            controller: provider.bankAccountNameController,
            labelText: 'Nama Pemilik Rekening',
            hintText: 'Nama sesuai rekening bank',
            prefixIcon: const Icon(Icons.person_rounded, size: 20),
          ),
          ModernTextFormField(
            controller: provider.bankAccountNoController,
            labelText: 'Nomor Rekening / IBAN',
            hintText: 'Nomor rekening atau IBAN',
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      );
    }

    return FormSectionCard(
      title: 'Pembayaran',
      subtitle: 'QRIS & rekening bank — opsional',
      icon: Icons.payments_outlined,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final scanned = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _QrisScannerPage()),
                  );
                  if (scanned != null && context.mounted) {
                    context.read<SupplierProvider>().qrisController.text =
                        scanned;
                    await _validateQris(context);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan QRIS'),
                style: AppButtonStyle.outlined(
                    minimumSize: const Size(0, 44)),
              ),
            ),
            AppSpacing.gapHorizontalSM,
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _decodeQrisFromGallery(context),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Dari Galeri'),
                style: AppButtonStyle.outlined(
                    minimumSize: const Size(0, 44)),
              ),
            ),
          ],
        ),
        ModernTextFormField(
          controller: provider.qrisController,
          labelText: 'QRIS Payload',
          hintText: 'Atau tempel payload QRIS di sini',
          prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
          maxLines: 2,
          onChanged: (_) => _validateQris(context),
        ),
        if (form.qrisValidating)
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              AppSpacing.gapHorizontalSM,
              Text('Memvalidasi QRIS…', style: theme.textTheme.bodySmall),
            ],
          )
        else if (form.qrisMerchantName != null)
          _buildQrisResult(theme, form),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        _buildDropdown<BankModel>(
          label: 'Bank',
          hint: 'Pilih bank (opsional)',
          icon: Icons.account_balance_rounded,
          value: form.selectedBank,
          items: form.banks,
          itemLabel: (b) => b.name,
          onChanged: (val) =>
              context.read<SupplierProvider>().setSelectedBank(val),
        ),
        ModernTextFormField(
          controller: provider.bankAccountNameController,
          labelText: 'Nama Pemilik Rekening',
          hintText: 'Nama sesuai rekening bank',
          prefixIcon: const Icon(Icons.person_rounded, size: 20),
        ),
        ModernTextFormField(
          controller: provider.bankAccountNoController,
          labelText: 'Nomor Rekening',
          hintText: 'Nomor rekening',
          prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  /// Strip hasil validasi QRIS — tint container primer (dunia charcoal/
  /// emas), nama merchant + NMID sebagai bukti identitas terverifikasi.
  Widget _buildQrisResult(ThemeData theme, SupplierFormState form) {
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, size: 16, color: cs.primary),
          AppSpacing.gapHorizontalSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Merchant terverifikasi: ${form.qrisMerchantName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (form.qrisNmid != null)
                  Text(
                    'NMID ${form.qrisNmid}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bar aksi bawah — tombol menyebut keadaan pembayaran: "Simpan tanpa
  /// pembayaran" saat zona kosong, "Simpan lengkap" saat terisi.
  /// Padding & inset sistem bawah ditangani SafeBottomBar di AppPageScaffold.
  Widget _buildBottomBar(
    BuildContext context,
    SupplierProvider provider,
    SupplierFormState form,
  ) {
    return ListenableBuilder(
      listenable: _paymentListen(),
      builder: (context, _) {
        final hasPayment = _hasPayment(provider, form);
        return ModernButton(
          text: hasPayment ? 'Simpan lengkap' : 'Simpan tanpa pembayaran',
          onPressed: form.isSaving ? null : () => _submit(context),
          isLoading: form.isSaving,
        );
      },
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
    String Function(T)? itemSubtitle,
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
              Text(hint, style: Theme.of(context).textTheme.bodySmall),
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
            getSubtitle: itemSubtitle,
            onChanged: onChanged,
            validator: isRequired
                ? (v) => v == null ? '$label wajib dipilih' : null
                : null,
          );
  }
}

/// Kartu tonal dengan sudut garis putus — bahasa visual zona tertunda;
/// kode menggambar, bukan Card bersarang.
class _DashedCard extends StatelessWidget {
  final Widget child;

  const _DashedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        color: cs.outlineVariant,
        radius: AppSpacing.radiusLG,
        strokeWidth: 1.5,
        dashWidth: 6,
        dashGap: 5,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
          borderRadius: AppSpacing.borderRadiusLG,
        ),
        child: child,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Inset setengah stroke agar garis tidak memotong keluar sudut kartu.
    final inset = strokeWidth / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset, inset, size.width - inset * 2,
              size.height - inset * 2),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashGap;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, distance + length),
            paint,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashGap != dashGap;
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
      appBar: GlassAppBar(
        title: const Text('Scan QRIS Supplier'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller!,
            builder: (context, state, child) {
              return BarButtonCluster(
                actions: [
                  BarButtonSpec(
                    icon: state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                    tooltip: 'Senter',
                    onTap: () => _controller!.toggleTorch(),
                  ),
                ],
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.surface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
