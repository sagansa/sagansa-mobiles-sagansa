import 'dart:io';

import 'package:flutter/material.dart';

import '../models/delivery_address_model.dart';
import '../models/sales_order_employee_model.dart';
import '../models/store_model.dart';
import '../services/image_service.dart';
import '../services/image_upload_service.dart';
import '../services/sales_order_employee_service.dart';
import '../services/store_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/snackbar_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/forms/form_image_tile.dart';
import '../widgets/forms/form_item_card.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_date_field.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_form_field.dart';
import 'delivery_address_form_page.dart';

/// Form create/update penjualan employee (role sales).
///
/// [order] null → mode create. [order] tidak null → mode edit (hanya untuk
/// order milik sendiri yang belum valid / belum locked).
class SalesOrderEmployeeFormPage extends StatefulWidget {
  final SalesOrderEmployeeModel? order;
  const SalesOrderEmployeeFormPage({super.key, this.order});

  @override
  State<SalesOrderEmployeeFormPage> createState() =>
      _SalesOrderEmployeeFormPageState();
}

class _FormItem {
  int? productId;
  String? productName;
  String? unit;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  _FormItem({
    this.productId,
    this.productName,
    this.unit,
    int quantity = 1,
    int unitPrice = 0,
  })  : qtyController = TextEditingController(text: '$quantity'),
        priceController =
            TextEditingController(text: FormatUtils.formatAmount(unitPrice));

  int get quantity => int.tryParse(qtyController.text) ?? 0;
  int get unitPrice => parseAmountInt(priceController.text);
  int get subtotal => quantity * unitPrice;

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}

class _SalesOrderEmployeeFormPageState
    extends State<SalesOrderEmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final SalesOrderEmployeeService _service = SalesOrderEmployeeService();
  final StoreService _storeService = StoreService();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Master data
  List<StoreModel> _stores = [];
  List<Map<String, dynamic>> _transferAccounts = [];
  List<Map<String, dynamic>> _deliveryAddresses = [];
  List<Map<String, dynamic>> _products = [];

  // Form state
  StoreModel? _store;
  DateTime? _deliveryDate;
  Map<String, dynamic>? _transferAccount;
  Map<String, dynamic>? _deliveryAddress;
  final List<_FormItem> _items = [];
  String? _imagePath; // path lokal untuk preview
  String? _uploadedImagePath; // path yang dikirim ke backend
  final _notesController = TextEditingController();

  bool get _isEdit => widget.order != null;

  @override
  void initState() {
    super.initState();
    _loadSupportingData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSupportingData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getSupportingData(),
        _storeService.getStores(),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final stores = results[1] as List<StoreModel>;
      if (!mounted) return;

      setState(() {
        _transferAccounts = (data['transfer_to_accounts'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _deliveryAddresses = (data['delivery_addresses'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _products = (data['products'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _stores = stores;

        // Prefill untuk edit mode
        if (_isEdit) _prefillFromOrder();

        // Default store: kalau create, ambil store pertama
        _store ??= _stores.isNotEmpty ? _stores.first : null;
        _transferAccount ??=
            _transferAccounts.isNotEmpty ? _transferAccounts.first : null;
        _deliveryAddress ??=
            _deliveryAddresses.isNotEmpty ? _deliveryAddresses.first : null;
        _deliveryDate ??= DateTime.now();

        if (_items.isEmpty) _items.add(_FormItem());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _prefillFromOrder() {
    final o = widget.order!;
    _store = _stores.where((s) => s.id == o.storeId).firstOrNull;
    _deliveryDate = o.deliveryDate;
    _transferAccount = _transferAccounts
        .where((e) => e['id'] == o.transferToAccountId)
        .firstOrNull;
    _deliveryAddress = _deliveryAddresses
        .where((e) => e['id'] == o.deliveryAddressId)
        .firstOrNull;
    _uploadedImagePath = o.imagePayment;
    _notesController.text = o.notes ?? '';
    _items
      ..clear()
      ..addAll(o.items.map((i) => _FormItem(
            productId: i.productId,
            productName: i.productName,
            unit: i.productUnit,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
          )));
  }

  int get _total => _items.fold(0, (sum, i) => sum + i.subtotal);

  Future<void> _pickImage() async {
    // Pipeline standar: dialog sumber → pick native terkompresi.
    final photo = await ImageService.selectAndPickImage(context);
    if (photo == null || !mounted) return;
    setState(() => _imagePath = photo.path);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Buka form konsumen baru. Bila tersimpan, tambahkan ke daftar alamat
  /// pengiriman (format `{id, name}`) dan pilih langsung untuk order ini.
  Future<void> _openCreateDeliveryAddress() async {
    final created = await Navigator.push<DeliveryAddressModel>(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryAddressFormPage()),
    );
    if (created == null || !mounted) return;
    setState(() {
      final entry = {'id': created.id, 'name': created.displayName};
      _deliveryAddresses = [
        ..._deliveryAddresses.where((e) => e['id'] != created.id),
        entry,
      ];
      _deliveryAddress = entry;
    });
  }

  void _addItem() {
    setState(() => _items.add(_FormItem()));
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    // Validasi tambahan: minimal 1 item dengan product terisi.
    final validItems = _items.where((i) => i.productId != null).toList();
    if (validItems.isEmpty) {
      SnackbarUtils.warning(context, 'Tambahkan minimal 1 produk.');
      return;
    }
    if (_store == null ||
        _deliveryDate == null ||
        _transferAccount == null ||
        _deliveryAddress == null) {
      SnackbarUtils.warning(context, 'Lengkapi semua field wajib.');
      return;
    }

    setState(() => _saving = true);

    try {
      // Upload image bila ada yang baru dipilih.
      String? imagePath = _uploadedImagePath;
      if (_imagePath != null) {
        final uploaded = await ImageUploadService.upload(
          File(_imagePath!),
          directory: 'images/Employee',
        );
        if (uploaded == null) {
          throw Exception('Gagal upload bukti transfer.');
        }
        imagePath = uploaded;
      }

      final itemsPayload = validItems
          .map((i) => {
                'product_id': i.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
              })
          .toList();

      if (_isEdit) {
        await _service.update(
          widget.order!.id,
          storeId: _store!.id,
          deliveryDate: _fmt(_deliveryDate!),
          deliveryAddressId: _deliveryAddress!['id'] as int,
          transferToAccountId: _transferAccount!['id'] as int,
          imagePayment: imagePath,
          clearImage: imagePath == null,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          items: itemsPayload,
        );
      } else {
        await _service.create(
          storeId: _store!.id,
          deliveryDate: _fmt(_deliveryDate!),
          deliveryAddressId: _deliveryAddress!['id'] as int,
          transferToAccountId: _transferAccount!['id'] as int,
          imagePayment: imagePath,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          items: itemsPayload,
        );
      }

      if (!mounted) return;
      SnackbarUtils.success(
          context, _isEdit ? 'Penjualan diperbarui.' : 'Penjualan dibuat.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(
          context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text(_isEdit ? 'Edit Penjualan' : 'Penjualan Baru'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadSupportingData)
              : Form(
                  key: _formKey,
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.translucent,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ).copyWith(top: AppBarInsets.top(context)),
                      children: [
                        // Section 1: Informasi Penjualan
                        FormSectionCard(
                          title: 'Informasi Penjualan',
                          icon: Icons.receipt_long_outlined,
                          children: [
                            ModernDropdown<StoreModel>(
                              value: _store,
                              labelText: 'Toko',
                              hint: 'Pilih toko...',
                              isRequired: true,
                              prefixIcon:
                                  const Icon(Icons.storefront, size: 20),
                              items: _stores,
                              getLabel: (s) => s.nickname,
                              onChanged: (v) => setState(() => _store = v),
                              validator: (v) => v == null ? 'Pilih toko' : null,
                            ),
                            ModernDateField(
                              value: _deliveryDate,
                              labelText: 'Tanggal Pengiriman',
                              isRequired: true,
                              firstDate: DateTime(DateTime.now().year - 1),
                              lastDate: DateTime(DateTime.now().year + 1),
                              onChanged: (d) {
                                if (d != null) {
                                  setState(() => _deliveryDate = d);
                                }
                              },
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ModernDropdown<Map<String, dynamic>>(
                                  value: _deliveryAddress,
                                  labelText: 'Alamat Pengiriman (Konsumen)',
                                  hint: 'Pilih konsumen...',
                                  isRequired: true,
                                  prefixIcon: const Icon(
                                      Icons.location_on_outlined,
                                      size: 20),
                                  items: _deliveryAddresses,
                                  getLabel: (e) => e['name']?.toString() ?? '-',
                                  onChanged: (v) =>
                                      setState(() => _deliveryAddress = v),
                                  validator: (v) =>
                                      v == null ? 'Pilih konsumen' : null,
                                ),
                                const SizedBox(height: 2),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : _openCreateDeliveryAddress,
                                    icon: const Icon(
                                        Icons.person_add_alt_outlined,
                                        size: 16),
                                    label: const Text('Tambah Konsumen Baru'),
                                    style: AppButtonStyle.text(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ModernDropdown<Map<String, dynamic>>(
                              value: _transferAccount,
                              labelText: 'Rekening Tujuan Transfer',
                              hint: 'Pilih rekening...',
                              isRequired: true,
                              prefixIcon:
                                  const Icon(Icons.credit_card, size: 20),
                              items: _transferAccounts,
                              getLabel: (e) => e['name']?.toString() ?? '-',
                              onChanged: (v) =>
                                  setState(() => _transferAccount = v),
                              validator: (v) =>
                                  v == null ? 'Pilih rekening tujuan' : null,
                            ),
                            ModernTextFormField(
                              controller: _notesController,
                              labelText: 'Catatan (opsional)',
                              hintText: 'Tambahkan catatan khusus bila ada',
                              prefixIcon: const Icon(Icons.chat_bubble_outline,
                                  size: 20),
                              maxLines: 2,
                            ),
                            FormImageTile(
                              imageFile:
                                  _imagePath != null ? File(_imagePath!) : null,
                              imageUrl: _imagePath == null
                                  ? (widget.order?.imagePaymentUrl)
                                  : null,
                              label: 'Bukti Transfer Pembayaran',
                              hint: 'Lampirkan foto struk / resi transfer',
                              onPick: _pickImage,
                              onRemove: (_imagePath != null ||
                                      _uploadedImagePath != null)
                                  ? () => setState(() {
                                        _imagePath = null;
                                        _uploadedImagePath = null;
                                      })
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Section 2: Detail Item Produk
                        FormSectionCard(
                          title: 'Item Produk',
                          icon: Icons.inventory_2_outlined,
                          trailing: FormAddButton(
                            label: 'Tambah',
                            onPressed: _addItem,
                          ),
                          children: [
                            if (_items.isEmpty)
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: AppSpacing.borderRadiusMD,
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.shopping_bag_outlined,
                                        size: 32,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5)),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Belum ada produk ditambahkan',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tekan "Tambah" di kanan atas untuk memilih produk.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._items.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                return FormItemCard(
                                  index: idx,
                                  onDelete: _items.length > 1
                                      ? () => _removeItem(idx)
                                      : null,
                                  productField: ModernDropdown<int>(
                                    value: item.productId,
                                    labelText: 'Produk',
                                    hint: 'Pilih produk...',
                                    items: _products
                                        .map((p) => p['id'] as int)
                                        .toList(),
                                    getLabel: (v) {
                                      final p = _products.firstWhere(
                                          (e) => e['id'] == v,
                                          orElse: () => {});
                                      return '${p['name'] ?? ''} (${p['unit'] ?? ''})';
                                    },
                                    getSubtitle: (v) {
                                      final p = _products.firstWhere(
                                          (e) => e['id'] == v,
                                          orElse: () => {});
                                      return 'Rp ${p['price'] ?? 0}';
                                    },
                                    onChanged: (v) {
                                      if (v == null) return;
                                      final p = _products
                                          .firstWhere((e) => e['id'] == v);
                                      setState(() {
                                        item.productId = v;
                                        item.productName =
                                            p['name']?.toString();
                                        item.unit = p['unit']?.toString();
                                        final defaultPrice =
                                            p['price'] as int? ?? 0;
                                        if (item.unitPrice == 0 &&
                                            defaultPrice > 0) {
                                          item.priceController.text =
                                              FormatUtils.formatAmount(
                                                  defaultPrice);
                                        }
                                      });
                                    },
                                  ),
                                  qtyField: TextFormField(
                                    controller: item.qtyController,
                                    keyboardType: TextInputType.number,
                                    onTap: () {
                                      item.qtyController.selection =
                                          TextSelection(
                                        baseOffset: 0,
                                        extentOffset:
                                            item.qtyController.text.length,
                                      );
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Qty',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 9,
                                      ),
                                      suffixText: item.unit,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  priceField: TextFormField(
                                    controller: item.priceController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: rupiahInputFormatters,
                                    onTap: () {
                                      item.priceController.selection =
                                          TextSelection(
                                        baseOffset: 0,
                                        extentOffset:
                                            item.priceController.text.length,
                                      );
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Harga Satuan',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 9,
                                      ),
                                      prefixText: 'Rp ',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  subtotalText:
                                      FormatUtils.formatCurrency(item.subtotal),
                                );
                              }),

                            // Total summary strip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withValues(alpha: 0.35),
                                borderRadius: AppSpacing.borderRadiusMD,
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.payments_outlined,
                                          size: 18, color: colorScheme.primary),
                                      AppSpacing.gapHorizontalSM,
                                      Text(
                                        'Total Nilai Penjualan',
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    FormatUtils.formatCurrency(_total),
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapVerticalMD,
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: GlassContainer.bottomBar(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.lg),
        child: ModernButton(
          text: _isEdit ? 'Simpan Perubahan' : 'Simpan Penjualan',
          onPressed: _saving ? null : _save,
          isLoading: _saving,
          icon: Icons.save_outlined,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            AppSpacing.gapVerticalSM,
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
