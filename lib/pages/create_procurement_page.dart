import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../models/store_model.dart';
import '../../services/procurement_service.dart';
import '../../services/store_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_picker_sheet.dart';
import '../widgets/safe_bottom_bar.dart';

class CreateProcurementPage extends StatefulWidget {
  const CreateProcurementPage({super.key});

  @override
  State<CreateProcurementPage> createState() => _CreateProcurementPageState();
}

class _CreateProcurementPageState extends State<CreateProcurementPage> {
  final StoreService _storeService = StoreService();
  final ProcurementService _procurementService = ProcurementService();

  List<StoreModel> _stores = [];
  List<ProcurementProduct> _products = [];
  bool _isLoadingData = true;
  String? _errorMessage;

  StoreModel? _selectedStore;
  final List<Map<String, dynamic>> _selectedItems =
      []; // Contains product_id, productName, unitName, quantity_plan
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final stores = await _storeService.getStores();
      final products = await _procurementService.getProducts();
      setState(() {
        _stores = stores;
        _products = products;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data awal: $e';
        _isLoadingData = false;
      });
    }
  }

  void _showAddItemBottomSheet() {
    int? selectedPaymentType = 1;
    ProcurementProduct? selectedProduct;
    final qtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final theme = Theme.of(modalContext);
          final cs = theme.colorScheme;
          final bottomPadding = MediaQuery.of(modalContext).viewInsets.bottom +
              modalContext.systemBottomInset;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalContext).size.height * 0.85,
            ),
            margin: EdgeInsets.only(bottom: bottomPadding),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: AppSpacing.borderRadiusXS,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tambah Item Request',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Produk',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          AppSpacing.gapVerticalSM,
                          InkWell(
                            onTap: () async {
                              final result = await _showProductSearchDialog();
                              if (result != null) {
                                setModalState(() {
                                  selectedProduct = result;
                                  selectedPaymentType =
                                      result.paymentTypeId ?? 1;
                                });
                              }
                            },
                            borderRadius: AppSpacing.borderRadiusLG,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selectedProduct != null
                                    ? cs.primary.withValues(alpha: 0.05)
                                    : cs.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                borderRadius: AppSpacing.borderRadiusLG,
                                border: Border.all(
                                  color: selectedProduct != null
                                      ? cs.primary.withValues(alpha: 0.4)
                                      : cs.outlineVariant
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: selectedProduct != null
                                          ? cs.primary.withValues(alpha: 0.12)
                                          : cs.surfaceContainerHighest,
                                      borderRadius: AppSpacing.borderRadiusMD,
                                    ),
                                    child: Icon(
                                      selectedProduct != null
                                          ? Icons.inventory_2_rounded
                                          : Icons.add_shopping_cart_rounded,
                                      color: selectedProduct != null
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedProduct != null
                                              ? selectedProduct!.name
                                              : 'Pilih produk belanja...',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: selectedProduct != null
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: selectedProduct != null
                                                ? cs.onSurface
                                                : cs.onSurfaceVariant,
                                          ),
                                        ),
                                        if (selectedProduct != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Satuan: ${selectedProduct!.unitName}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AppSpacing.gapVerticalMD,
                          Text(
                            'Rencana Pembayaran',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          AppSpacing.gapVerticalSM,
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaymentTypeOption(
                                  context: modalContext,
                                  title: 'Transfer',
                                  icon: Icons.account_balance_rounded,
                                  isSelected: selectedPaymentType == 1,
                                  onTap: () => setModalState(
                                      () => selectedPaymentType = 1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaymentTypeOption(
                                  context: modalContext,
                                  title: 'Tunai / Cash',
                                  icon: Icons.payments_rounded,
                                  isSelected: selectedPaymentType == 2,
                                  onTap: () => setModalState(
                                      () => selectedPaymentType = 2),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapVerticalMD,
                          Text(
                            'Jumlah / Quantity',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          AppSpacing.gapVerticalSM,
                          TextFormField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              hintText: '0',
                              suffixText: selectedProduct?.unitName ?? '',
                              filled: true,
                              fillColor: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              border: OutlineInputBorder(
                                borderRadius: AppSpacing.borderRadiusLG,
                                borderSide: BorderSide(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppSpacing.borderRadiusLG,
                                borderSide: BorderSide(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Jumlah wajib diisi';
                              }
                              final num = double.tryParse(val);
                              if (num == null || num <= 0) {
                                return 'Jumlah harus lebih besar dari 0';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.gapVerticalLG,
                          ModernButton(
                            text: 'Tambah ke List',
                            height: 52,
                            onPressed: () {
                              if (selectedProduct == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Pilih produk terlebih dahulu.')),
                                );
                                return;
                              }
                              if (formKey.currentState!.validate()) {
                                final duplicateIndex = _selectedItems.indexWhere(
                                  (item) =>
                                      item['product_id'] ==
                                          selectedProduct!.id &&
                                      item['payment_type_id'] ==
                                          selectedPaymentType,
                                );

                                setState(() {
                                  if (duplicateIndex != -1) {
                                    _selectedItems[duplicateIndex]
                                            ['quantity_plan'] +=
                                        double.parse(qtyController.text);
                                  } else {
                                    _selectedItems.add({
                                      'product_id': selectedProduct!.id,
                                      'productName': selectedProduct!.name,
                                      'unitName': selectedProduct!.unitName,
                                      'quantity_plan':
                                          double.parse(qtyController.text),
                                      'payment_type_id': selectedPaymentType,
                                    });
                                  }
                                });
                                Navigator.pop(ctx);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: modalContext.systemBottomInset + 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentTypeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusLG,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: AppSpacing.borderRadiusLG,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            AppSpacing.gapHorizontalSM,
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih toko terlebih dahulu.')),
      );
      return;
    }

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item belanja.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final List<Map<String, dynamic>> itemsApi = _selectedItems.map((item) {
        return {
          'product_id': item['product_id'],
          'quantity_plan': item['quantity_plan'],
          'payment_type_id': item['payment_type_id'],
        };
      }).toList();

      await _procurementService.createRequest(_selectedStore!.id, itemsApi);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request Purchase berhasil dibuat.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat request: $e')),
      );
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
        title: const Text('Buat Request Baru'),
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
                    FormSectionCard(
                      title: 'Toko Pemohon',
                      subtitle:
                          'Pilih outlet cabang yang mengajukan request belanja',
                      icon: Icons.storefront_rounded,
                      child: ModernDropdown<StoreModel>(
                        labelText: 'Pilih Toko / Outlet',
                        hint: 'Pilih outlet...',
                        prefixIcon: const Icon(Icons.storefront, size: 20),
                        value: _selectedStore,
                        items: _stores,
                        getLabel: (s) => s.nickname,
                        getSubtitle: (s) => '',
                        onChanged: (s) {
                          setState(() {
                            _selectedStore = s;
                          });
                        },
                      ),
                    ),
                    AppSpacing.gapVerticalMD,
                    FormSectionCard(
                      title: 'Item Request (${_selectedItems.length})',
                      subtitle:
                          'Daftar kebutuhan bahan atau produk yang diajukan',
                      icon: Icons.shopping_basket_outlined,
                      trailing: ModernButton(
                        text: 'Tambah Item',
                        icon: Icons.add_rounded,
                        variant: ModernButtonVariant.outlined,
                        fullWidth: false,
                        height: 36,
                        onPressed: _showAddItemBottomSheet,
                      ),
                      child: _selectedItems.isEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xl,
                                horizontal: AppSpacing.md,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.35),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada item request',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    AppSpacing.gapVerticalXS,
                                    Text(
                                      'Tekan tombol "+ Tambah Item" di atas untuk menambahkan daftar belanja.',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (int idx = 0;
                                    idx < _selectedItems.length;
                                    idx++) ...[
                                  Builder(builder: (context) {
                                    final item = _selectedItems[idx];
                                    final isCash = item['payment_type_id'] == 2;
                                    final qty = item['quantity_plan'];
                                    final qtyStr = qty.toStringAsFixed(
                                        qty == qty.roundToDouble() ? 0 : 2);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerLowest,
                                        borderRadius: AppSpacing.borderRadiusMD,
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: (isCash
                                                      ? AppColors.warning
                                                      : AppColors.success)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  AppSpacing.borderRadiusSM,
                                            ),
                                            child: Icon(
                                              isCash
                                                  ? Icons.payments_outlined
                                                  : Icons
                                                      .account_balance_outlined,
                                              color: isCash
                                                  ? AppColors.warning
                                                  : AppColors.success,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['productName'] ?? '',
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                AppSpacing.gapVerticalXS,
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: (isCash
                                                                ? AppColors
                                                                    .warning
                                                                : AppColors
                                                                    .success)
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        isCash
                                                            ? 'Tunai'
                                                            : 'Transfer',
                                                        style: textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                          color: isCash
                                                              ? AppColors
                                                                  .warning
                                                              : AppColors
                                                                  .success,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    AppSpacing.gapHorizontalSM,
                                                    Text(
                                                      '$qtyStr ${item['unitName'] ?? ''}',
                                                      style: textTheme.bodySmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Hapus',
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: colorScheme.error
                                                  .withValues(alpha: 0.8),
                                              size: 22,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _selectedItems.removeAt(idx);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (idx < _selectedItems.length - 1)
                                    AppSpacing.gapVerticalSM,
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeBottomBar(
        child: ModernButton(
          text: 'Kirim Request Belanja',
          onPressed: _isSubmitting ? null : _submitRequest,
          isLoading: _isSubmitting,
          height: 52,
        ),
      ),
    );
  }

  Future<ProcurementProduct?> _showProductSearchDialog() {
    return ModernPickerSheet.show<ProcurementProduct>(
      context: context,
      title: 'Pilih Produk Belanja',
      items: _products
          .map((p) => ModernPickerItem<ProcurementProduct>(
                value: p,
                label: p.name,
                subtitle: 'Satuan: ${p.unitName}',
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ))
          .toList(),
      searchable: true,
      searchHint: 'Cari nama produk...',
    );
  }
}
