import 'package:flutter/material.dart';

import '../models/employee_consumption_model.dart';
import '../models/store_model.dart';
import '../services/employee_consumption_service.dart';
import '../services/store_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/safe_bottom_bar.dart';

class CreateEmployeeConsumptionPage extends StatefulWidget {
  final EmployeeConsumptionModel? consumption;

  const CreateEmployeeConsumptionPage({super.key, this.consumption});

  @override
  State<CreateEmployeeConsumptionPage> createState() =>
      _CreateEmployeeConsumptionPageState();
}

class _CreateEmployeeConsumptionPageState
    extends State<CreateEmployeeConsumptionPage> {
  final StoreService _storeService = StoreService();
  final EmployeeConsumptionService _service = EmployeeConsumptionService();

  List<StoreModel> _stores = [];
  bool _isLoadingData = true;
  String? _errorMessage;

  StoreModel? _selectedStore;
  DateTime? _selectedDate;
  final List<Map<String, dynamic>> _items = [];
  bool _isSubmitting = false;

  bool get isEditing => widget.consumption != null;

  bool get _isLocked =>
      isEditing && widget.consumption!.status == 2; // Valid tidak bisa diubah

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    for (var item in _items) {
      (item['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final stores = await _storeService.getStores();
      final products = await _service.getProducts();

      final editing = widget.consumption;
      if (editing != null) {
        _selectedStore =
            stores.where((s) => s.id == editing.storeId).firstOrNull;
        _selectedDate = DateTime.tryParse(editing.date);
      }

      _items.clear();
      for (var p in products) {
        final existing =
            editing?.details.where((d) => d.productId == p.id).firstOrNull;
        final controller = TextEditingController(
          text: existing != null ? _qtyText(existing.quantity) : '0',
        );
        _items.add({
          'product_id': p.id,
          'productName': p.name,
          'unitName': p.unitName,
          'controller': controller,
        });
      }

      setState(() {
        _stores = stores;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data awal: $e';
        _isLoadingData = false;
      });
    }
  }

  String _qtyText(double qty) {
    final clean = qty.toStringAsFixed(0);
    return qty == qty.truncateToDouble() ? clean : qty.toString();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gagal Menyimpan',
            style: Theme.of(ctx)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(ctx).colorScheme.error)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
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
  }

  Future<void> _submitReport() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih toko terlebih dahulu.')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal wajib diisi.')),
      );
      return;
    }

    final validItems = _items.where((item) {
      final ctrl = item['controller'] as TextEditingController;
      return (double.tryParse(ctrl.text) ?? 0) > 0;
    }).toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Isi minimal satu item dengan jumlah > 0.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final itemsApi = validItems.map((item) {
        final ctrl = item['controller'] as TextEditingController;
        return {
          'product_id': item['product_id'],
          'quantity': double.tryParse(ctrl.text) ?? 0.0,
        };
      }).toList();

      final dateStr =
          '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

      if (isEditing) {
        await _service.updateEmployeeConsumption(
          widget.consumption!.id,
          _selectedStore!.id,
          dateStr,
          itemsApi,
        );
      } else {
        await _service.createEmployeeConsumption(
          _selectedStore!.id,
          dateStr,
          itemsApi,
        );
      }

      if (!mounted) return;
      showSuccessSnackBar(
        context,
        isEditing
            ? 'Sisa stok karyawan berhasil diperbarui.'
            : 'Sisa stok karyawan berhasil disimpan.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '');
      if (message.contains('valid') || message.contains('tidak dapat diubah')) {
        _showErrorDialog(message);
      } else {
        showErrorSnackBar(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      // extendBody tetap false: jika true, konten bawah form tertutup bar aksi
      // (bar sudah meng-handle system inset sendiri lewat SafeBottomBar).
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(
            isEditing ? 'Edit Sisa Stok Karyawan' : 'Sisa Stok Karyawan Baru'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!,
                            style: textTheme.bodyLarge
                                ?.copyWith(color: colorScheme.error)),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton(
                          onPressed: _loadInitialData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppBarInsets.top(context) + AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl * 2,
                  ),
                  children: [
                    if (_isLocked) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: AppSpacing.borderRadiusMD,
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 20, color: AppColors.warning),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Data berstatus Valid dan tidak dapat diubah.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapVerticalMD,
                    ],

                    // Section 1: Lokasi & Tanggal Toko
                    FormSectionCard(
                      title: 'Lokasi & Tanggal Toko',
                      subtitle: 'Pilih cabang dan tanggal pencatatan sisa stok',
                      icon: Icons.storefront_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ModernDropdown<StoreModel>(
                            labelText: 'Pilih Toko',
                            hint: 'Pilih toko...',
                            prefixIcon: const Icon(Icons.storefront, size: 20),
                            value: _selectedStore,
                            items: _stores,
                            enabled: !_isLocked,
                            getLabel: (s) => s.nickname,
                            getSubtitle: (s) => '',
                            onChanged: (val) {
                              setState(() {
                                _selectedStore = val;
                              });
                            },
                          ),
                          AppSpacing.gapVerticalMD,
                          _buildDateField(colorScheme),
                        ],
                      ),
                    ),
                    AppSpacing.gapVerticalMD,

                    // Section 2: Sisa Stok
                    FormSectionCard(
                      title: 'Sisa Stok Karyawan',
                      subtitle: 'Catat sisa stok yang belum terjual oleh karyawan',
                      icon: Icons.person_outline_rounded,
                      child: Column(
                        children: [
                          for (int i = 0; i < _items.length; i++) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLowest,
                                borderRadius: AppSpacing.borderRadiusSM,
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _items[i]['productName'] ?? '',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (_items[i]['unitName'] != null)
                                          Text(
                                            'Satuan: ${_items[i]['unitName']}',
                                            style: textTheme.bodySmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  AppSpacing.gapHorizontalMD,
                                  SizedBox(
                                    width: 110,
                                    child: TextFormField(
                                      controller: _items[i]['controller'],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.end,
                                      enabled: !_isLocked,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.sm,
                                        ),
                                        suffixText: _items[i]['unitName'],
                                        suffixStyle:
                                            textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      onTap: () {
                                        final ctrl = _items[i]['controller']
                                            as TextEditingController;
                                        ctrl.selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset: ctrl.text.length,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < _items.length - 1) AppSpacing.gapVerticalSM,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _isLocked
          ? null
          : SafeBottomBar(
              child: ModernButton(
                text: isEditing ? 'Simpan Perubahan' : 'Simpan Sisa Stok',
                icon: isEditing ? Icons.save_rounded : Icons.add_circle_rounded,
                onPressed: _isSubmitting ? null : _submitReport,
                isLoading: _isSubmitting,
              ),
            ),
    );
  }

  Widget _buildDateField(ColorScheme colorScheme) {
    return InkWell(
      onTap: _isLocked ? null : _pickDate,
      borderRadius: AppSpacing.borderRadiusSM,
      child: InputDecorator(
        isEmpty: _selectedDate == null,
        decoration: InputDecoration(
          labelText: 'Tanggal *',
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
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
}
