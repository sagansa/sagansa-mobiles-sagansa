import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/closing_store_service.dart';
import '../services/fuel_service_service.dart';
import '../services/image_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/error_state.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/forms/form_image_tile.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_date_field.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_form_field.dart';
import '../widgets/supplier_picker_modal.dart';

/// Halaman form tambah transaksi bensin (fuel) atau servis kendaraan baru.
///
/// Mengusung desain modern Sagansa Mobile berstandar Impeccable:
/// - Hero Interactive Type Selector (Bensin vs Servis)
/// - Segmented cards menggunakan [FormSectionCard]
/// - Pratinjau nota hemat ruang dengan [FormImageTile]
/// - Kontrol tanggal modern dengan [ModernDateField]
/// - Input terintegrasi tema dengan [ModernTextFormField] & [ModernDropdown]
class FuelServiceFormPage extends StatefulWidget {
  final int? closingStoreId;
  final bool isCashOnly;

  const FuelServiceFormPage({
    super.key,
    this.closingStoreId,
    this.isCashOnly = false,
  });

  @override
  State<FuelServiceFormPage> createState() => _FuelServiceFormPageState();
}

class _FuelServiceFormPageState extends State<FuelServiceFormPage> {
  final ClosingStoreService _lookupService = ClosingStoreService();
  final FuelServiceService _service = FuelServiceService();
  final _formKey = GlobalKey<FormState>();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<dynamic> _vehicles = [];
  List<dynamic> _suppliers = [];

  // Form states
  DateTime _selectedDate = DateTime.now();
  int _selectedType = 1; // 1 = Fuel, 2 = Service
  int? _selectedVehicleId;
  double? _vehicleLastKm; // KM terakhir kendaraan terpilih (untuk validasi).
  int? _selectedSupplierId;
  int _selectedPaymentType = 2; // 2 = Tunai, 1 = Transfer

  final _kmController = TextEditingController(text: '0');
  final _literController = TextEditingController(text: '0');
  final _amountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final List<Map<String, dynamic>> _serviceServiceDetails = [];
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.isCashOnly || widget.closingStoreId != null) {
      _selectedPaymentType = 2;
    }
    _loadFormData();
  }

  @override
  void dispose() {
    _kmController.dispose();
    _literController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (var detail in _serviceServiceDetails) {
      (detail['nameController'] as TextEditingController).dispose();
      (detail['costController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final vehiclesData = await _lookupService.getVehicles();
      final suppliersData = await _lookupService.getSuppliers();
      if (!mounted) return;
      setState(() {
        _vehicles = vehiclesData;
        _suppliers = suppliersData;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoadingData = false;
      });
    }
  }

  void _updateServiceAmount() {
    if (_selectedType == 2) {
      double total = 0;
      for (var detail in _serviceServiceDetails) {
        total += parseAmount(
                (detail['costController'] as TextEditingController).text) ??
            0;
      }
      _amountController.text = FormatUtils.formatAmount(total);
    }
  }

  void _addServiceItem() {
    setState(() {
      _serviceServiceDetails.add({
        'nameController': TextEditingController(),
        'costController': TextEditingController(text: '0'),
      });
    });
  }

  void _removeServiceItem(int index) {
    setState(() {
      final item = _serviceServiceDetails.removeAt(index);
      (item['nameController'] as TextEditingController).dispose();
      (item['costController'] as TextEditingController).dispose();
      _updateServiceAmount();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      showAppSnackBar(
        context,
        'Foto bukti / nota struk wajib diunggah!',
        background: AppColors.error,
      );
      return;
    }

    if (_selectedType == 2 && _serviceServiceDetails.isEmpty) {
      showAppSnackBar(
        context,
        'Mohon tambahkan minimal 1 rincian item servis.',
        background: AppColors.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        if (widget.closingStoreId != null)
          'closing_store_id': widget.closingStoreId,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'fuel_service': _selectedType,
        'vehicle_id': _selectedVehicleId,
        if (_selectedSupplierId != null) 'supplier_id': _selectedSupplierId,
        'payment_type_id': _selectedPaymentType,
        'km': double.tryParse(_kmController.text) ?? 0,
        'liter': double.tryParse(_literController.text) ?? 0,
        'amount': parseAmount(_amountController.text) ?? 0,
        'notes': _notesController.text.trim(),
        if (_selectedType == 2)
          'service_details': _serviceServiceDetails.map((d) {
            return {
              'name':
                  (d['nameController'] as TextEditingController).text.trim(),
              'price': parseAmount(
                      (d['costController'] as TextEditingController).text) ??
                  0,
            };
          }).toList(),
      };

      final result =
          await _service.createFuelService(payload, imageFile: _selectedImage);

      if (mounted) {
        showSuccessSnackBar(
            context, 'Transaksi bensin/servis berhasil disimpan.');
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Gagal menyimpan transaksi: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
      setState(() => _isSubmitting = false);
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
        title: Text(widget.closingStoreId != null
            ? 'Tambah Bensin / Servis (Shift)'
            : 'Tambah Bensin / Servis'),
        centerTitle: true,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: ErrorState(
                      message: _errorMessage!,
                      onRetry: _loadFormData,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding
                        .copyWith(top: AppBarInsets.top(context)),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Hero Type Selector Card (Bensin vs Servis)
                          _buildTypeSelector(theme, colorScheme),
                          const SizedBox(height: AppSpacing.sectionGap),

                          // 2. Section: Waktu & Metode Pembayaran
                          _buildDateTimeAndPaymentSection(colorScheme),
                          const SizedBox(height: AppSpacing.sectionGap),

                          // 3. Section: Armada & Rekanan
                          _buildVehicleAndSupplierSection(theme, colorScheme),
                          const SizedBox(height: AppSpacing.sectionGap),

                          // 4. Section: Odometer & Rincian Biaya
                          _buildCostAndDetailsSection(theme, colorScheme),
                          const SizedBox(height: AppSpacing.sectionGap),

                          // 5. Section: Bukti Nota & Catatan
                          _buildPhotoAndNotesSection(colorScheme),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// Selector interaktif untuk memilih antara pengeluaran Bensin atau Servis.
  Widget _buildTypeSelector(ThemeData theme, ColorScheme colorScheme) {
    final isFuel = _selectedType == 1;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeOption(
              isSelected: isFuel,
              icon: Icons.local_gas_station_rounded,
              title: 'Bensin (Fuel)',
              subtitle: 'Pengisian BBM armada',
              accentColor: AppColors.success,
              colorScheme: colorScheme,
              onTap: () {
                if (!isFuel) {
                  setState(() {
                    _selectedType = 1;
                    _amountController.text = '0';
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTypeOption(
              isSelected: !isFuel,
              icon: Icons.build_circle_rounded,
              title: 'Servis (Maintenance)',
              subtitle: 'Perawatan & perbaikan',
              accentColor: AppColors.warning,
              colorScheme: colorScheme,
              onTap: () {
                if (isFuel) {
                  setState(() {
                    _selectedType = 2;
                    if (_serviceServiceDetails.isEmpty) {
                      _addServiceItem();
                    }
                    _updateServiceAmount();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMD,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.8)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: AppSpacing.paddingSM,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color:
                      isSelected ? accentColor : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? accentColor
                                : colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                AppSpacing.gapHorizontalXS,
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: accentColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Section 1: Tanggal Transaksi & Tipe Pembayaran (Tunai vs Transfer).
  Widget _buildDateTimeAndPaymentSection(ColorScheme colorScheme) {
    return FormSectionCard(
      title: 'Waktu & Pembayaran',
      subtitle: 'Tanggal transaksi dan metode pembayaran',
      icon: Icons.event_note_outlined,
      children: [
        ModernDateField(
          labelText: 'Tanggal Transaksi',
          isRequired: true,
          value: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 60)),
          lastDate: DateTime.now(),
          onChanged: (date) {
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
        ),
        AppSpacing.gapVerticalXS,
        Text(
          'Metode Pembayaran *',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        if (widget.isCashOnly || widget.closingStoreId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: AppSpacing.borderRadiusSM,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tunai (Kas Toko Shift)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Langsung memotong saldo kas laci shift toko aktif',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: AppSpacing.borderRadiusXS,
                  ),
                  child: Text(
                    'Tutup Shift',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildPaymentTypeOption(
                  label: 'Tunai (Kas Toko)',
                  icon: Icons.payments_outlined,
                  value: 2,
                  colorScheme: colorScheme,
                ),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                child: _buildPaymentTypeOption(
                  label: 'Transfer Bank',
                  icon: Icons.account_balance_outlined,
                  value: 1,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPaymentTypeOption({
    required String label,
    required IconData icon,
    required int value,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedPaymentType == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentType = value),
        borderRadius: AppSpacing.borderRadiusSM,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: AppSpacing.borderRadiusSM,
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              AppSpacing.gapHorizontalSM,
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section 2: Kendaraan Armada & Rekanan / Supplier / SPBU.
  Widget _buildVehicleAndSupplierSection(
      ThemeData theme, ColorScheme colorScheme) {
    final selectedSupplier = _selectedSupplierId != null
        ? _suppliers.firstWhere(
            (s) => s['id'] == _selectedSupplierId,
            orElse: () => null,
          )
        : null;

    return FormSectionCard(
      title: 'Kendaraan & Rekanan',
      subtitle: 'Armada operasional dan tempat pembelian/servis',
      icon: Icons.directions_car_outlined,
      children: [
        ModernDropdown<int>(
          labelText: 'Pilih Kendaraan',
          hint: 'Pilih armada kendaraan...',
          isRequired: true,
          prefixIcon: const Icon(Icons.directions_car_outlined, size: 20),
          value: _selectedVehicleId,
          items: _vehicles.map((v) => v['id'] as int).toList(),
          getLabel: (val) {
            final v = _vehicles.firstWhere(
              (e) => e['id'] == val,
              orElse: () => {},
            );
            return v['no_register']?.toString() ?? '';
          },
          getSubtitle: (val) {
            final v = _vehicles.firstWhere(
              (e) => e['id'] == val,
              orElse: () => {},
            );
            return v['name']?.toString() ?? '';
          },
          onChanged: (val) {
            setState(() {
              _selectedVehicleId = val;
              final v = _vehicles.firstWhere(
                (e) => e['id'] == val,
                orElse: () => {},
              );
              final lastKm = v['last_km'];
              _vehicleLastKm = lastKm is num
                  ? lastKm.toDouble()
                  : double.tryParse(lastKm?.toString() ?? '');

              // Pre-fill KM dengan last_km bila kosong/0
              if ((_kmController.text.isEmpty ||
                      (double.tryParse(_kmController.text) ?? 0) <= 0) &&
                  _vehicleLastKm != null) {
                _kmController.text = _vehicleLastKm!.toStringAsFixed(0);
              }
            });
          },
          validator: (val) => val == null ? 'Pilih kendaraan armada' : null,
        ),
        if (_vehicleLastKm != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 14, color: AppColors.info),
                AppSpacing.gapHorizontalXS,
                Text(
                  'KM terakhir tercatat: ${_vehicleLastKm!.toStringAsFixed(0)} km',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),

        // Supplier Picker
        Text(
          'Supplier / Rekanan SPBU / Bengkel (Opsional)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        InkWell(
          onTap: () async {
            final res = await SupplierPickerModal.show(
              context: context,
              suppliers: _suppliers,
              selectedSupplierId: _selectedSupplierId,
            );
            if (res != null) {
              setState(() => _selectedSupplierId = res['id']);
            }
          },
          borderRadius: AppSpacing.borderRadiusMD,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: AppSpacing.borderRadiusMD,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 20,
                  color: selectedSupplier != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: selectedSupplier != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedSupplier['name']?.toString() ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                            ),
                            if (selectedSupplier['address'] != null &&
                                selectedSupplier['address']
                                    .toString()
                                    .isNotEmpty)
                              Text(
                                selectedSupplier['address'].toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        )
                      : Text(
                          'Pilih SPBU atau Bengkel...',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                ),
                if (selectedSupplier != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () => setState(() => _selectedSupplierId = null),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Hapus Rekanan',
                  )
                else
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Section 3: Input Odometer KM & Rincian Biaya (Bensin vs Servis).
  Widget _buildCostAndDetailsSection(ThemeData theme, ColorScheme colorScheme) {
    final isFuel = _selectedType == 1;

    return FormSectionCard(
      title:
          isFuel ? 'Odometer & Pengisian Bensin' : 'Odometer & Rincian Servis',
      subtitle: isFuel
          ? 'Catat posisi kilometer, liter, dan total nominal pembelian BBM'
          : 'Catat posisi kilometer dan rincian perbaikan / suku cadang',
      icon: isFuel ? Icons.speed_rounded : Icons.build_outlined,
      children: [
        ModernTextFormField(
          controller: _kmController,
          labelText: 'KM Odometer Saat Ini',
          isRequired: true,
          prefixIcon: const Icon(Icons.speed_rounded, size: 20),
          suffixText: 'km',
          keyboardType: TextInputType.number,
          validator: (val) {
            final km = double.tryParse(val ?? '') ?? 0;
            if (km <= 0) {
              return 'KM harus lebih besar dari 0';
            }
            if (_vehicleLastKm != null && km < _vehicleLastKm!) {
              return 'KM tidak boleh mundur dari ${_vehicleLastKm!.toStringAsFixed(0)} km';
            }
            return null;
          },
        ),

        // Mode Bensin (Fuel)
        if (isFuel) ...[
          ModernTextFormField(
            controller: _literController,
            labelText: 'Jumlah Liter BBM',
            prefixIcon: const Icon(Icons.opacity_rounded, size: 20),
            suffixText: 'liter',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          ModernTextFormField(
            controller: _amountController,
            labelText: 'Total Biaya Pembelian BBM',
            isRequired: true,
            prefixIcon: const Icon(Icons.payments_outlined, size: 20),
            prefixText: 'Rp ',
            keyboardType: TextInputType.number,
            inputFormatters: rupiahInputFormatters,
            validator: (val) {
              final amt = parseAmount(val ?? '') ?? 0;
              if (amt <= 0) {
                return 'Masukkan nominal total biaya BBM';
              }
              return null;
            },
          ),
        ],

        // Mode Servis (Service)
        if (!isFuel) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rincian Item Servis (${_serviceServiceDetails.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              FormAddButton(
                label: 'Tambah Item',
                onPressed: _addServiceItem,
              ),
            ],
          ),

          if (_serviceServiceDetails.isEmpty)
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingMD,
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: AppSpacing.borderRadiusMD,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 32,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Belum ada rincian item servis',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  AppSpacing.gapVerticalSM,
                  OutlinedButton.icon(
                    onPressed: _addServiceItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah Item Servis'),
                  ),
                ],
              ),
            ),

          ..._serviceServiceDetails.asMap().entries.map((entry) {
            final idx = entry.key;
            final detail = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: AppSpacing.borderRadiusMD,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: AppSpacing.borderRadiusXS,
                        ),
                        child: Text(
                          '#${idx + 1}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      AppSpacing.gapHorizontalSM,
                      Expanded(
                        child: ModernTextFormField(
                          controller:
                              detail['nameController'] as TextEditingController,
                          labelText: 'Nama Item / Suku Cadang / Jasa',
                          isRequired: true,
                          prefixIcon:
                              const Icon(Icons.settings_outlined, size: 18),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ),
                      AppSpacing.gapHorizontalXS,
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: colorScheme.error,
                        tooltip: 'Hapus Item',
                        onPressed: () => _removeServiceItem(idx),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalSM,
                  ModernTextFormField(
                    controller:
                        detail['costController'] as TextEditingController,
                    labelText: 'Biaya Item (Rp)',
                    isRequired: true,
                    prefixText: 'Rp ',
                    prefixIcon:
                        const Icon(Icons.attach_money_rounded, size: 18),
                    keyboardType: TextInputType.number,
                    inputFormatters: rupiahInputFormatters,
                    onChanged: (_) => _updateServiceAmount(),
                    validator: (val) {
                      final price = parseAmount(val ?? '') ?? 0;
                      if (price <= 0) {
                        return 'Biaya harus > 0';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            );
          }),

          // Ringkasan Total Biaya Servis Otomatis
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderRadius: AppSpacing.borderRadiusMD,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: AppSpacing.paddingSM,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusSM,
                  ),
                  child: Icon(
                    Icons.calculate_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Biaya Servis',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormatter.format(
                          parseAmount(_amountController.text) ?? 0,
                        ),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: AppSpacing.borderRadiusXS,
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        'Auto-calc',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Section 4: Bukti Nota / Struk & Catatan Tambahan.
  Widget _buildPhotoAndNotesSection(ColorScheme colorScheme) {
    return FormSectionCard(
      title: 'Bukti Struk & Catatan',
      subtitle: 'Lampiran foto nota pembayaran dan keterangan tambahan',
      icon: Icons.receipt_long_outlined,
      children: [
        FormImageTile(
          imageFile: _selectedImage,
          label: 'Foto Nota / Struk Bukti',
          hint: 'Format foto struk pengisian atau kuitansi bengkel',
          isRequired: true,
          onPick: () async {
            final File? file = await ImageService.selectAndPickImage(context);
            if (file != null) {
              setState(() => _selectedImage = file);
            }
          },
          onRemove: () => setState(() => _selectedImage = null),
        ),
        const SizedBox(height: 6),
        ModernTextFormField(
          controller: _notesController,
          labelText: 'Catatan Tambahan (Opsional)',
          hintText: 'Tuliskan rincian tambahan, nama petugas, kondisi, dll...',
          prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
          maxLines: 3,
        ),
      ],
    );
  }

  /// Bottom action bar dengan tombol Simpan bertema modern glassmorphism.
  Widget _buildBottomBar() {
    return GlassContainer.bottomBar(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: ModernButton(
        text: 'Simpan Transaksi',
        icon: Icons.check_circle_outline,
        onPressed: _isSubmitting ? null : _submit,
        isLoading: _isSubmitting,
      ),
    );
  }
}
