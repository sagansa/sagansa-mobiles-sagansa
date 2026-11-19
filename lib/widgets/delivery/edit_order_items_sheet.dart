import 'package:flutter/material.dart';

import '../../models/sales_order_online_model.dart';
import '../../providers/delivery_provider.dart';
import '../../services/sales_order_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/format_utils.dart';
import '../../utils/text_formatters.dart';
import '../../widgets/modern_dropdown.dart';
import '../app_snackbar.dart';
import '../safe_bottom_bar.dart';

/// Bottom sheet untuk admin mengubah rincian produk sebuah order:
/// ganti produk, jumlah, harga satuan, tambah/hapus item, plus ongkos
/// kirim (ikut terkirim ke server; total = barang + ongkos kirim).
/// Menggantikan pesan lama "hubungi admin backend untuk mengubah jenis
/// produk".
class EditOrderItemsSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final DeliveryProvider provider;

  /// Injectable untuk test; default service produksi.
  final SalesOrderService? salesOrderService;

  const EditOrderItemsSheet({
    super.key,
    required this.order,
    required this.provider,
    this.salesOrderService,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> order,
    required DeliveryProvider provider,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditOrderItemsSheet(order: order, provider: provider),
    );
  }

  @override
  State<EditOrderItemsSheet> createState() => _EditOrderItemsSheetState();
}

class _EditOrderItemsSheetState extends State<EditOrderItemsSheet> {
  late final SalesOrderService _salesOrderService;

  List<SalesOrderOnlineProduct> _products = [];
  final List<_EditItemState> _items = [];
  late final TextEditingController _shippingController;
  bool _isLoadingProducts = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _salesOrderService = widget.salesOrderService ?? SalesOrderService();
    _shippingController = TextEditingController(
      text: _toMoneyText(widget.order['shipping_cost']),
    );
    _seedFromOrder();
    _loadProducts();
  }

  void _seedFromOrder() {
    final items = widget.order['items'];
    if (items is List) {
      for (final raw in items) {
        if (raw is Map<String, dynamic>) {
          _items.add(_EditItemState(
            productId: raw['product_id'] == null
                ? null
                : int.tryParse('${raw['product_id']}'),
            productOnlineGroupId: raw['product_online_group_id'] == null
                ? null
                : int.tryParse('${raw['product_online_group_id']}'),
            groupName: raw['product_name']?.toString(),
            qtyController: TextEditingController(
              text: _toText(raw['quantity'], fallback: '1'),
            ),
            priceController: TextEditingController(
              text: _toMoneyText(raw['unit_price']),
            ),
          ));
        }
      }
    }
    if (_items.isEmpty) {
      _addItem();
    }
  }

  static String _toText(dynamic value, {String fallback = '0'}) {
    if (value == null) return fallback;
    final parsed = int.tryParse(value.toString());
    if (parsed == null) {
      final parsedDouble = double.tryParse(value.toString());
      return parsedDouble == null ? fallback : parsedDouble.round().toString();
    }
    return parsed.toString();
  }

  static String _toMoneyText(dynamic value) {
    if (value == null) return '0';
    final parsed =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    return FormatUtils.formatAmount(parsed);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _loadError = null;
    });
    try {
      final products = await _salesOrderService.getOnlineProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _loadError = 'Gagal memuat daftar produk: $e';
      });
    }
  }

  void _addItem() {
    setState(() {
      _items.add(_EditItemState(
        productId: null,
        qtyController: TextEditingController(text: '1'),
        priceController: TextEditingController(text: '0'),
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  int get _itemsTotal {
    int total = 0;
    for (final item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  /// Ongkos kirim yang akan dikirim ke server — selalu terkirim (0 bila
  /// dikosongkan) supaya admin bisa menghapus ongkos kirim yang salah.
  int get _shippingCost => parseAmountInt(_shippingController.text);

  int get _grandTotal => _itemsTotal + _shippingCost;

  Future<void> _save() async {
    if (_items.isEmpty) {
      _showSnack('Minimal harus ada 1 item.');
      return;
    }
    for (final item in _items) {
      if (!item.isGroupItem && item.productId == null) {
        _showSnack('Ada item yang belum dipilih produknya.');
        return;
      }
      if (item.quantity < 1) {
        _showSnack('Jumlah minimal 1.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      await widget.provider.updateOrderItems(
        [
          for (final item in _items)
            {
              'product_id': item.isGroupItem ? null : item.productId,
              if (item.isGroupItem)
                'product_online_group_id': item.productOnlineGroupId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
            },
        ],
        shippingCost: _shippingCost,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnackBar(
        context,
        'Rincian produk berhasil diperbarui.',
        background: AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSnack(String message) {
    showAppSnackBar(context, message, background: AppColors.error);
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _shippingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom +
        context.systemBottomInset;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: AppSpacing.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: colorScheme.primary, size: 20),
                    AppSpacing.gapHorizontalSM,
                    Expanded(
                      child: Text(
                        'Ubah Rincian Produk • Order #${widget.order['id']}',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (_isLoadingProducts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(_loadError!,
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.error)),
                        AppSpacing.gapVerticalSM,
                        OutlinedButton.icon(
                          onPressed: _loadProducts,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          _buildItemCard(context, index),
                    ),
                  ),
                if (!_isLoadingProducts && _loadError == null) ...[
                  const Divider(height: 24),
                  // Ongkos kirim — selalu tampil supaya admin bisa menaikkan/
                  // menurunkan/menghapus nilai; total akhir = barang + ongkir.
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shippingController,
                          keyboardType: TextInputType.number,
                          inputFormatters: rupiahInputFormatters,
                          decoration: const InputDecoration(
                            labelText: 'Ongkos Kirim',
                            prefixText: 'Rp ',
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      AppSpacing.gapHorizontalMD,
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Barang: Rp ${FormatUtils.formatAmount(_itemsTotal)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalSM,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        'Rp ${_grandTotal.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.')}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalSM,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _addItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah Item'),
                        ),
                      ),
                      AppSpacing.gapHorizontalMD,
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, int index) {
    final item = _items[index];
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      // Kunci per baris supaya Element tidak dicocokkan by posisi saat
      // baris dihapus/bergeser — state TextFormField (nama paket read-only)
      // tidak pindah antar baris.
      key: ObjectKey(item),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: colorScheme.error),
                    onPressed: () => _removeItem(index),
                    tooltip: 'Hapus item',
                  ),
              ],
            ),
            if (item.isGroupItem)
              TextFormField(
                initialValue: item.groupName ?? 'Paket #${item.productOnlineGroupId}',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Paket (tetap)',
                  isDense: true,
                ),
              )
            else
              ModernDropdown<int>(
                value: item.productId,
                hint: 'Pilih produk',
                labelText: 'Produk',
                items: [for (final p in _products) p.id],
                getLabel: (id) => _products
                    .firstWhere(
                      (p) => p.id == id,
                      orElse: () => SalesOrderOnlineProduct(
                          id: id, name: 'Produk #$id', unit: ''),
                    )
                    .name,
                searchable: true,
                isRequired: true,
                onChanged: (value) => setState(() => item.productId = value),
              ),
            AppSpacing.gapVerticalMD,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(
                  child: TextField(
                    controller: item.priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: rupiahInputFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Harga Satuan',
                      prefixText: 'Rp ',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            AppSpacing.gapVerticalSM,
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: Rp ${item.subtotal.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.')}',
                style:
                    textTheme.bodySmall?.copyWith(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditItemState {
  int? productId;
  int? productOnlineGroupId;

  /// Nama grup/produk dari server — baris grup tampil read-only.
  final String? groupName;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  _EditItemState({
    required this.productId,
    required this.qtyController,
    required this.priceController,
    this.productOnlineGroupId,
    this.groupName,
  });

  bool get isGroupItem => productOnlineGroupId != null;

  int get quantity => int.tryParse(qtyController.text) ?? 0;
  int get unitPrice => parseAmountInt(priceController.text);
  int get subtotal => quantity * unitPrice;

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}
