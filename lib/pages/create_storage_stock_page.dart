import 'package:flutter/material.dart';

import '../models/storage_stock_model.dart';
import '../models/store_model.dart';
import '../services/storage_stock_service.dart';
import '../services/store_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/safe_bottom_bar.dart';

class CreateStorageStockPage extends StatefulWidget {
  /// Mode edit: laporan yang kuantitasnya dikoreksi. Null = mode create.
  final StorageStockModel? reportForEdit;

  /// Injection untuk widget test; null = pakai service sungguhan.
  final StoreService? storeService;
  final StorageStockService? storageStockService;

  const CreateStorageStockPage({
    super.key,
    this.reportForEdit,
    this.storeService,
    this.storageStockService,
  });

  @override
  State<CreateStorageStockPage> createState() => _CreateStorageStockPageState();
}

class _CreateStorageStockPageState extends State<CreateStorageStockPage> {
  late final StoreService _storeService;
  late final StorageStockService _storageStockService;

  List<StoreModel> _stores = [];
  List<StorageStockProduct> _products = [];
  bool _isLoadingData = true;
  String? _errorMessage;

  StoreModel? _selectedStore;
  final List<Map<String, dynamic>> _items = [];
  bool _isSubmitting = false;

  bool get _isEditMode => widget.reportForEdit != null;

  @override
  void initState() {
    super.initState();
    _storeService = widget.storeService ?? StoreService();
    _storageStockService = widget.storageStockService ?? StorageStockService();
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
      final products = await _storageStockService.getProducts();

      setState(() {
        _stores = stores;
        _products = products;

        _items.clear();
        for (var p in _products) {
          final controller = TextEditingController(
            text: _isEditMode ? _initialQuantityFor(p.id) : '0',
          );
          controller.addListener(() {
            final text = controller.text;
            if (text.startsWith('0') && text.length > 1) {
              controller.text = text.substring(1);
              controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length));
            }
          });

          _items.add({
            'product_id': p.id,
            'productName': p.name,
            'unitName': p.unitName,
            'controller': controller,
          });
        }

        if (_isEditMode) {
          _selectedStore = _storeFromList(widget.reportForEdit!.storeId);
        }

        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data awal: $e';
        _isLoadingData = false;
      });
    }
  }

  String _initialQuantityFor(int productId) {
    if (widget.reportForEdit == null) return '0';
    try {
      final detail = widget.reportForEdit!.details
          .firstWhere((d) => d.productId == productId);
      return detail.quantity.toStringAsFixed(
        detail.quantity.truncateToDouble() == detail.quantity ? 0 : 2,
      );
    } catch (_) {
      return '0';
    }
  }

  StoreModel? _storeFromList(int storeId) {
    try {
      return _stores.firstWhere((s) => s.id == storeId);
    } catch (_) {
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Gagal Menyimpan',
          style: Theme.of(ctx)
              .textTheme
              .titleMedium
              ?.copyWith(color: Theme.of(ctx).colorScheme.error),
        ),
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

  Future<void> _submit() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih gudang/outlet.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final itemsApi = _items.map((item) {
        final ctrl = item['controller'] as TextEditingController;
        final qty = double.tryParse(ctrl.text) ?? 0.0;
        return {
          'product_id': item['product_id'],
          'quantity': qty,
        };
      }).toList();

      if (_isEditMode) {
        await _storageStockService.updateStorageStock(
            widget.reportForEdit!.id, itemsApi);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Laporan Stock Opname berhasil diperbarui.')),
        );
      } else {
        await _storageStockService.createStorageStock(
            _selectedStore!.id, itemsApi);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Laporan Stock Opname berhasil disimpan.')),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
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
        title: Text(_isEditMode ? 'Edit Stock Opname' : 'Stock Opname Baru'),
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
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppBarInsets.top(context),
                    AppSpacing.md,
                    AppSpacing.md + context.systemBottomInset + 72,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormSectionCard(
                        title: 'Lokasi Stock Opname',
                        subtitle: _isEditMode
                            ? 'Outlet terkunci saat mode koreksi laporan'
                            : 'Pilih gudang atau outlet untuk opname fisik',
                        icon: Icons.storefront_rounded,
                        children: [
                          ModernDropdown<StoreModel>(
                            labelText: 'Gudang / Outlet',
                            hint: 'Pilih outlet...',
                            isRequired: true,
                            prefixIcon: const Icon(Icons.storefront, size: 20),
                            value: _selectedStore,
                            items: _stores,
                            getLabel: (s) => s.nickname,
                            getSubtitle: (s) => '',
                            enabled: !_isEditMode,
                            onChanged: (val) {
                              setState(() {
                                _selectedStore = val;
                              });
                            },
                          ),
                        ],
                      ),
                      AppSpacing.gapVerticalMD,
                      FormSectionCard(
                        title: 'Kuantitas Fisik Aktual',
                        subtitle: 'Masukkan jumlah stok riil hasil penghitungan fisik',
                        icon: Icons.inventory_2_outlined,
                        children: [
                          if (_items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'Tidak ada produk tersedia untuk diopname.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ..._items.map((item) {
                            final unit = item['unitName']?.toString() ?? '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.25),
                                borderRadius: AppSpacing.borderRadiusMD,
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
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
                                          item['productName'] ?? '',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (unit.isNotEmpty)
                                          Text(
                                            'Satuan: $unit',
                                            style:
                                                textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 110,
                                    child: TextFormField(
                                      controller: item['controller'],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.end,
                                      decoration: InputDecoration(
                                        suffixText: unit.isNotEmpty ? unit : null,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 10),
                                        filled: true,
                                        fillColor: colorScheme.surface,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              AppSpacing.borderRadiusMD,
                                          borderSide: BorderSide(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              AppSpacing.borderRadiusMD,
                                          borderSide: BorderSide(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                      onTap: () {
                                        final ctrl = item['controller']
                                            as TextEditingController;
                                        ctrl.selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset: ctrl.text.length);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeBottomBar(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ModernButton(
            text: _isEditMode
                ? 'Simpan Perubahan Stock Opname'
                : 'Simpan Stock Opname',
            onPressed: _isSubmitting ? null : _submit,
            isLoading: _isSubmitting,
          ),
        ),
      ),
    );
  }
}
