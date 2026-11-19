import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/image_service.dart';
import '../../services/presence_service.dart';
import '../../services/procurement_service.dart';
import '../../services/supplier_service.dart';
import '../../theme/app_spacing.dart';
import '../models/procurement_model.dart';
import '../utils/text_formatters.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/safe_bottom_bar.dart';

class CreateInvoiceFormPage extends StatefulWidget {
  const CreateInvoiceFormPage({super.key});

  @override
  State<CreateInvoiceFormPage> createState() => _CreateInvoiceFormPageState();
}

class _CreateInvoiceFormPageState extends State<CreateInvoiceFormPage> {
  final ProcurementService _procurementService = ProcurementService();
  final SupplierService _supplierService = SupplierService();

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isAdmin = false;

  int? _selectedSupplierId;
  String _selectedSupplierName = '';
  int? _storeId;
  String _storeName = '';
  int _paymentTypeId = 2;
  DateTime _selectedDate = DateTime.now();
  int _taxes = 0;
  int _discounts = 0;
  final _taxesController = TextEditingController(text: '0');
  final _discountsController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _detailRequests = [];
  final List<Map<String, dynamic>> _items = [];
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final roles = List<String>.from(json.decode(userString)['roles'] ?? []);
      if (mounted) {
        setState(() {
          _isAdmin = roles.contains('admin') || roles.contains('super_admin');
        });
      }
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _taxesController.dispose();
    _discountsController.dispose();
    _notesController.dispose();
    for (var item in _items) {
      (item['priceCtrl'] as TextEditingController).dispose();
      (item['qtyCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final presence = await PresenceService().getUserPresence();
      final today = presence['data']?['today'];
      final storeId = today?['store_id'];
      final storeName = today?['store'] ?? '';

      if (storeId == null) {
        setState(() {
          _errorMessage = 'Anda belum melakukan clock-in.';
          _isLoadingData = false;
        });
        return;
      }

      _storeId = int.tryParse(storeId.toString());
      _storeName = storeName.toString();

      final requests = await _procurementService.getDetailRequests(
        storeId: _storeId!,
        paymentTypeId: _paymentTypeId,
      );
      setState(() {
        _detailRequests = requests;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data: $e';
        _isLoadingData = false;
      });
    }
  }

  Future<void> _reloadDetailRequests(int paymentTypeId) async {
    if (_storeId == null) return;
    try {
      final requests = await _procurementService.getDetailRequests(
        storeId: _storeId!,
        paymentTypeId: paymentTypeId,
      );
      setState(() => _detailRequests = requests);
    } catch (_) {}
  }

  void _addItem() {
    setState(() {
      _items.add({
        'detail_request_id': null,
        'productName': null,
        'unitName': null,
        'priceCtrl': TextEditingController(text: '0'),
        'qtyCtrl': TextEditingController(text: '1'),
      });
    });
  }

  void _removeItem(int index) {
    (_items[index]['priceCtrl'] as TextEditingController).dispose();
    (_items[index]['qtyCtrl'] as TextEditingController).dispose();
    setState(() => _items.removeAt(index));
  }

  int _itemSubtotal(Map<String, dynamic> item) {
    final price =
        parseAmountInt((item['priceCtrl'] as TextEditingController).text);
    final qty =
        int.tryParse((item['qtyCtrl'] as TextEditingController).text) ?? 0;
    return price * qty;
  }

  int get _subtotalPrice {
    int total = 0;
    for (var item in _items) {
      if (item['detail_request_id'] != null) {
        total += _itemSubtotal(item);
      }
    }
    return total;
  }

  int get _totalPrice => _subtotalPrice + _taxes - _discounts;

  Future<void> _pickSupplier() async {
    List<dynamic> suppliers;
    try {
      final list = await _supplierService.getSuppliers();
      suppliers = list.map((s) => {'id': s.id, 'name': s.name}).toList();
    } catch (_) {
      suppliers = [];
    }

    if (suppliers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada supplier tersedia.')),
      );
      return;
    }

    String query = '';
    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = suppliers.where((s) {
              if (query.isEmpty) return true;
              return (s['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase());
            }).toList();
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xxl + AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: AppSpacing.paddingSM,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cari supplier...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setDialogState(() => query = v),
                      autofocus: true,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Tidak ada supplier'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) => ListTile(
                              title: Text(filtered[i]['name'] ?? ''),
                              onTap: () => Navigator.pop(ctx, {
                                'id': filtered[i]['id'],
                                'name': filtered[i]['name'],
                              }),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        _selectedSupplierId = result['id'];
        _selectedSupplierName = result['name'];
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickImage() async {
    try {
      final photo = await ImageService.selectAndPickImage(context);
      if (photo != null && mounted) {
        setState(() => _imageFile = photo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih supplier terlebih dahulu.')),
      );
      return;
    }
    if (_items.isEmpty || _items.every((i) => i['detail_request_id'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item produk.')),
      );
      return;
    }
    if (!_isAdmin && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto invoice wajib diunggah.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final items =
          _items.where((i) => i['detail_request_id'] != null).map((i) {
        return {
          'detail_request_id': i['detail_request_id'],
          'quantity_product':
              int.tryParse((i['qtyCtrl'] as TextEditingController).text) ?? 1,
          'subtotal_invoice': _itemSubtotal(i),
        };
      }).toList();

      await _procurementService.createInvoiceStandalone(
        supplierId: _selectedSupplierId!,
        storeId: _storeId!,
        paymentTypeId: _paymentTypeId,
        date: dateStr,
        items: items,
        taxes: _taxes,
        discounts: _discounts,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        image: _imageFile,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice berhasil dibuat.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat invoice: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        title: const Text('Buat Invoice'),
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
                        Icon(Icons.error_outline,
                            size: 48, color: colorScheme.error),
                        AppSpacing.gapVerticalMD,
                        Text(_errorMessage!,
                            style: TextStyle(color: colorScheme.error)),
                      ],
                    ),
                  ),
                )
              : _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                      top: true,
                      bottom: false,
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: AppSpacing.paddingMD,
                              children: [
                                Card(
                                  elevation: 0,
                                  color: colorScheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppSpacing.borderRadiusLG,
                                    side: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: AppSpacing.paddingMD,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Informasi Toko & Supplier',
                                            style: textTheme.titleSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        AppSpacing.gapVerticalSM,
                                        Row(
                                          children: [
                                            Icon(Icons.store,
                                                size: 20,
                                                color: colorScheme
                                                    .onSurfaceVariant),
                                            AppSpacing.gapHorizontalSM,
                                            Text(_storeName,
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600)),
                                          ],
                                        ),
                                        AppSpacing.gapVerticalSM,
                                        InkWell(
                                          onTap: _pickSupplier,
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Supplier *',
                                              suffixIcon: Icon(Icons.search),
                                              isDense: true,
                                            ),
                                            child: Text(
                                              _selectedSupplierName.isEmpty
                                                  ? 'Pilih supplier'
                                                  : _selectedSupplierName,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: _selectedSupplierName
                                                        .isEmpty
                                                    ? colorScheme
                                                        .onSurfaceVariant
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                        AppSpacing.gapVerticalMD,
                                        DropdownButtonFormField<int>(
                                          initialValue: _paymentTypeId,
                                          decoration: const InputDecoration(
                                            labelText: 'Tipe Pembayaran *',
                                            isDense: true,
                                          ),
                                          items: [
                                            const DropdownMenuItem(
                                                value: 1,
                                                child: Text('Transfer')),
                                            const DropdownMenuItem(
                                                value: 2, child: Text('Tunai')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                  () => _paymentTypeId = val);
                                              _reloadDetailRequests(val);
                                            }
                                          },
                                        ),
                                        AppSpacing.gapVerticalSM,
                                        InkWell(
                                          onTap: _pickDate,
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Tanggal',
                                              prefixIcon: Icon(
                                                  Icons.calendar_today,
                                                  size: 20),
                                              isDense: true,
                                            ),
                                            child: Text(
                                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                AppSpacing.gapVerticalMD,
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Item Produk',
                                        style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                    FormAddButton(
                                      label: 'Tambah Item',
                                      onPressed: _addItem,
                                    ),
                                  ],
                                ),
                                if (_items.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.lg),
                                    child: Center(
                                      child: Text(
                                          'Belum ada item. Ketuk "Tambah Item" untuk mulai.',
                                          style: textTheme.bodyMedium?.copyWith(
                                              color: colorScheme
                                                  .onSurfaceVariant)),
                                    ),
                                  ),
                                ..._items.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final item = entry.value;
                                  final priceCtrl = item['priceCtrl']
                                      as TextEditingController;
                                  final qtyCtrl =
                                      item['qtyCtrl'] as TextEditingController;

                                  return Card(
                                    margin: EdgeInsets.only(
                                        bottom: AppSpacing.sectionGap),
                                    child: Padding(
                                      padding: AppSpacing.cardPadding,
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: DropdownButtonFormField<
                                                    int>(
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText: 'Produk',
                                                    isDense: true,
                                                  ),
                                                  initialValue:
                                                      item['detail_request_id'],
                                                  items: _detailRequests
                                                      .map<
                                                          DropdownMenuItem<
                                                              int>>((dr) =>
                                                          DropdownMenuItem<int>(
                                                            value: dr['id']
                                                                    is int
                                                                ? dr['id']
                                                                : int.parse(dr[
                                                                        'id']
                                                                    .toString()),
                                                            child: Text(
                                                              dr['detail_request_name'] ??
                                                                  dr['product']
                                                                      ?[
                                                                      'name'] ??
                                                                  '',
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ))
                                                      .toList(),
                                                  onChanged: (val) {
                                                    final dr = _detailRequests
                                                        .firstWhere(
                                                      (d) => d['id'] == val,
                                                      orElse: () =>
                                                          <String, dynamic>{},
                                                    );
                                                    // API mengirim riwayat harga sebagai list (maks. 5).
                                                    // Ambil harga terbaru untuk pengisian form, tanpa cast
                                                    // langsung yang akan gagal saat respons berupa JSArray.
                                                    final rawLpp = dr[
                                                        'last_purchase_price'];
                                                    final lppData = rawLpp
                                                            is List
                                                        ? (rawLpp.isNotEmpty &&
                                                                rawLpp.first
                                                                    is Map
                                                            ? Map<String,
                                                                    dynamic>.from(
                                                                rawLpp.first
                                                                    as Map)
                                                            : null)
                                                        : rawLpp is Map
                                                            ? Map<String,
                                                                    dynamic>.from(
                                                                rawLpp)
                                                            : null;
                                                    final lpp =
                                                        LastPurchasePrice
                                                            .fromJson(lppData);
                                                    setState(() {
                                                      item['detail_request_id'] =
                                                          val;
                                                      item['productName'] =
                                                          dr['detail_request_name'] ??
                                                              dr['product']
                                                                  ?['name'] ??
                                                              '';
                                                      item['unitName'] =
                                                          dr['product']?['unit']
                                                                  ?['unit'] ??
                                                              '';
                                                      item['lastPurchasePrice'] =
                                                          lpp;
                                                    });
                                                  },
                                                ),
                                              ),
                                              AppSpacing.gapHorizontalSM,
                                              IconButton(
                                                tooltip: 'Hapus',
                                                icon: const Icon(
                                                    Icons.delete_outline),
                                                color: colorScheme.error,
                                                onPressed: () =>
                                                    _removeItem(idx),
                                              ),
                                            ],
                                          ),
                                          if (item['detail_request_id'] !=
                                              null) ...[
                                            AppSpacing.gapVerticalSM,
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: qtyCtrl,
                                                    decoration: InputDecoration(
                                                      labelText: 'Jumlah',
                                                      suffixText:
                                                          item['unitName']
                                                              ?.toString(),
                                                      isDense: true,
                                                    ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    onTap: () {
                                                      qtyCtrl.selection =
                                                          TextSelection(
                                                        baseOffset: 0,
                                                        extentOffset:
                                                            qtyCtrl.text.length,
                                                      );
                                                    },
                                                    onChanged: (_) =>
                                                        setState(() {}),
                                                  ),
                                                ),
                                                AppSpacing.gapHorizontalSM,
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: priceCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText: 'Harga',
                                                      prefixText: 'Rp ',
                                                      isDense: true,
                                                    ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters:
                                                        rupiahInputFormatters,
                                                    onTap: () {
                                                      priceCtrl.selection =
                                                          TextSelection(
                                                        baseOffset: 0,
                                                        extentOffset: priceCtrl
                                                            .text.length,
                                                      );
                                                    },
                                                    onChanged: (_) =>
                                                        setState(() {}),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_isAdmin &&
                                                item['lastPurchasePrice'] !=
                                                    null &&
                                                (item['lastPurchasePrice']
                                                        as LastPurchasePrice)
                                                    .hasData) ...[
                                              AppSpacing.gapVerticalXS,
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      AppSpacing.borderRadiusSM,
                                                ),
                                                child: Text(
                                                  () {
                                                    final lpp = item[
                                                            'lastPurchasePrice']
                                                        as LastPurchasePrice;
                                                    final priceStr = lpp
                                                        .unitPrice
                                                        .toStringAsFixed(0)
                                                        .replaceAllMapped(
                                                            RegExp(
                                                                r'(\d)(?=(\d{3})+(?!\d))'),
                                                            (m) =>
                                                                '${m.group(1)}.');
                                                    final supplier = lpp
                                                                .supplierName !=
                                                            null
                                                        ? ' • ${lpp.supplierName}'
                                                        : '';
                                                    return 'Harga beli terakhir: Rp $priceStr/${item['unitName']}$supplier';
                                                  }(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: Colors.blue,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                ),
                                              ),
                                            ],
                                            if (_itemSubtotal(item) > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    'Subtotal: Rp ${_itemSubtotal(item).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.')}',
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                            color: colorScheme
                                                                .primary),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                AppSpacing.gapVerticalMD,
                                Card(
                                  elevation: 0,
                                  color: colorScheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppSpacing.borderRadiusLG,
                                    side: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: AppSpacing.paddingMD,
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: _taxesController,
                                          decoration: const InputDecoration(
                                            labelText: 'Pajak',
                                            prefixText: 'Rp ',
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters:
                                              rupiahInputFormatters,
                                          onTap: () {
                                            _taxesController.selection =
                                                TextSelection(
                                              baseOffset: 0,
                                              extentOffset:
                                                  _taxesController.text.length,
                                            );
                                          },
                                          onChanged: (v) => setState(
                                              () => _taxes = parseAmountInt(v)),
                                        ),
                                        AppSpacing.gapVerticalMD,
                                        TextFormField(
                                          controller: _discountsController,
                                          decoration: const InputDecoration(
                                            labelText: 'Diskon',
                                            prefixText: 'Rp ',
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters:
                                              rupiahInputFormatters,
                                          onTap: () {
                                            _discountsController.selection =
                                                TextSelection(
                                              baseOffset: 0,
                                              extentOffset: _discountsController
                                                  .text.length,
                                            );
                                          },
                                          onChanged: (v) => setState(() =>
                                              _discounts = parseAmountInt(v)),
                                        ),
                                        const Divider(height: 24),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total',
                                                style: textTheme.titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                            Text(
                                              'Rp ${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.')}',
                                              style: textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                AppSpacing.gapVerticalSM,

                                // Bukti/Foto Invoice
                                Text(
                                  _isAdmin
                                      ? 'Bukti/Foto Invoice'
                                      : 'Bukti/Foto Invoice (Wajib)',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_imageFile != null) ...[
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: AppSpacing.borderRadiusMD,
                                        child: Image.file(
                                          _imageFile!,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black
                                              .withValues(alpha: 0.6),
                                          radius: 18,
                                          child: IconButton(
                                            tooltip: 'Hapus',
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: Colors.white),
                                            onPressed: () => setState(
                                                () => _imageFile = null),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  AppSpacing.gapVerticalSM,
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _pickImage,
                                    icon: Icon(
                                      _imageFile == null
                                          ? Icons.add_a_photo_rounded
                                          : Icons.edit_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _imageFile == null
                                          ? 'Unggah Foto Invoice'
                                          : 'Ganti Foto Invoice',
                                    ),
                                  ),
                                ),
                                AppSpacing.gapVerticalSM,

                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Catatan',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: SafeBottomBar(
        child: ModernButton(
          text: 'Buat Invoice',
          icon: Icons.receipt_long_outlined,
          height: 52,
          onPressed: _isSubmitting ? null : _submit,
          isLoading: _isSubmitting,
        ),
      ),
    );
  }
}
