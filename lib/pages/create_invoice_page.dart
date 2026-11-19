import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/procurement_model.dart';
import '../../services/image_service.dart';
import '../../services/procurement_service.dart';
import '../../services/supplier_service.dart';
import '../../theme/app_spacing.dart';
import '../utils/text_formatters.dart';
import '../widgets/modern_button.dart';
import '../widgets/supplier_payment_info_card.dart';
import '../widgets/supplier_picker_modal.dart';

class CreateInvoicePage extends StatefulWidget {
  final int requestId;
  final List<int>? requestIds;
  final List<DetailRequestItem>? approvedItems;

  const CreateInvoicePage({
    super.key,
    required this.requestId,
    this.requestIds,
    this.approvedItems,
  });

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final ProcurementService _procurementService = ProcurementService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  bool _isSubmitting = false;
  bool _isLoading = true;

  int? _selectedSupplierId;
  String _selectedSupplierName = '';
  Map<String, dynamic>? _selectedSupplier;
  int _paymentTypeId = 2;
  int _taxes = 0;
  int _discounts = 0;
  final _taxesController = TextEditingController(text: '0');
  final _discountsController = TextEditingController(text: '0');

  /// Setiap item state terikat ke request asalnya (untuk invoice lintas-request).
  List<_ItemState> _itemStates = [];
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      // Jika approvedItems sudah diberikan (single request), gunakan apa adanya.
      if (widget.approvedItems != null) {
        _seedItems({
          widget.requestId: widget.approvedItems!,
        });
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Beberapa request -> kumpulkan item approved dari tiap request.
      final ids = widget.requestIds ?? [widget.requestId];
      final Map<int, List<DetailRequestItem>> grouped = {};
      for (final id in ids) {
        final req = await _procurementService.getRequestDetail(id);
        grouped[id] =
            req.detailRequests.where((i) => i.statusEnum.isApproved).toList();
      }
      if (mounted) {
        _seedItems(grouped);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat item: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _seedItems(Map<int, List<DetailRequestItem>> grouped) {
    _itemStates = grouped.entries.expand((entry) {
      final reqId = entry.key;
      return entry.value.map((item) {
        return _ItemState(
          requestId: reqId,
          detailRequest: item,
          priceController: TextEditingController(text: '0'),
          qtyCtrl: TextEditingController(
            text: item.quantityPlan.toStringAsFixed(
                item.quantityPlan == item.quantityPlan.roundToDouble() ? 0 : 2),
          ),
        );
      });
    }).toList();
  }

  @override
  void dispose() {
    _taxesController.dispose();
    _discountsController.dispose();
    for (var state in _itemStates) {
      state.priceController.dispose();
      state.qtyCtrl.dispose();
    }
    super.dispose();
  }

  int get _totalPrice {
    int total = 0;
    for (var state in _itemStates) {
      if (state.selected) {
        total += parseAmountInt(state.priceController.text);
      }
    }
    return total + _taxes - _discounts;
  }

  Future<void> _pickSupplier() async {
    final supplierService = SupplierService();
    List<dynamic> suppliers;
    try {
      final list = await supplierService.getSuppliers();
      suppliers = list
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'address': s.address,
                'no_telp': s.noTelp,
                'bank_name': s.bankName,
                'bank_account_name': s.bankAccountName,
                'bank_account_no': s.bankAccountNo,
                'qris': s.qris,
              })
          .toList();
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

    if (!mounted) return;
    final result = await SupplierPickerModal.show(
      context: context,
      suppliers: suppliers,
      selectedSupplierId: _selectedSupplierId,
    );
    if (result != null) {
      setState(() {
        _selectedSupplierId = result['id'];
        _selectedSupplierName = result['name'];
        _selectedSupplier = result;
      });
    }
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

    final selectedStates = _itemStates.where((s) => s.selected).toList();
    if (selectedStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 item.')),
      );
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto invoice wajib diunggah.')),
      );
      return;
    }

    final items = selectedStates.map((s) {
      final totalPrice = parseAmount(s.priceController.text) ?? 0;
      final qty = double.tryParse(s.qtyCtrl.text) ?? 0;

      return {
        'detail_request_id': s.detailRequest.id,
        'subtotal_invoice': totalPrice.round(),
        'quantity': qty.toInt(),
      };
    }).toList();

    // Kirim semua request-id terlibat agar backend mengizinkan item lintas-request.
    final allRequestIds = _itemStates.map((s) => s.requestId).toSet().toList();

    setState(() => _isSubmitting = true);
    try {
      final invoiceId = await _procurementService.createInvoice(
        widget.requestId,
        supplierId: _selectedSupplierId!,
        paymentTypeId: _paymentTypeId,
        items: items,
        taxes: _taxes,
        discounts: _discounts,
        requestIds: allRequestIds,
        image: _imageFile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice berhasil dibuat.')),
      );
      Navigator.pop(context, invoiceId);
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
      appBar: AppBar(
        title: const Text('Buat Invoice'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: AppSpacing.paddingMD,
                        children: [
                          InkWell(
                            onTap: _pickSupplier,
                            borderRadius: AppSpacing.borderRadiusXS,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Pilih Supplier *',
                                suffixIcon: Icon(Icons.search),
                              ),
                              child: Text(
                                _selectedSupplierName,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: _selectedSupplierName.isEmpty
                                      ? colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          if (_selectedSupplier != null) ...[
                            const SizedBox(height: 4),
                            SupplierPaymentInfoCard(
                                selectedSupplier: _selectedSupplier),
                          ],
                          AppSpacing.gapVerticalMD,
                          DropdownButtonFormField<int>(
                            initialValue: _paymentTypeId,
                            decoration: const InputDecoration(
                              labelText: 'Tipe Pembayaran *',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 1, child: Text('Transfer')),
                              DropdownMenuItem(value: 2, child: Text('Tunai')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _paymentTypeId = val);
                              }
                            },
                          ),
                          AppSpacing.gapVerticalLG,
                          Text(
                            'Pilih Item & Masukkan Harga',
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: AppSpacing.sectionGap),
                          ..._buildGroupedItems(theme, colorScheme),
                          AppSpacing.gapVerticalMD,

                          // Pajak & Diskon
                          Card(
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
                                    inputFormatters: rupiahInputFormatters,
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
                                    inputFormatters: rupiahInputFormatters,
                                    onTap: () {
                                      _discountsController.selection =
                                          TextSelection(
                                        baseOffset: 0,
                                        extentOffset:
                                            _discountsController.text.length,
                                      );
                                    },
                                    onChanged: (v) => setState(
                                        () => _discounts = parseAmountInt(v)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AppSpacing.gapVerticalMD,

                          // Bukti/Foto Invoice
                          Text(
                            'Bukti/Foto Invoice (Wajib)',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_imageFile != null) ...[
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMD),
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
                                    backgroundColor:
                                        Colors.black.withValues(alpha: 0.6),
                                    radius: 18,
                                    child: IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: Colors.white),
                                      onPressed: () =>
                                          setState(() => _imageFile = null),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                        ],
                      ),
                    ),
                    Container(
                      padding: AppSpacing.paddingMD,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  'Rp ${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.')}',
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.gapVerticalSM,
                            ModernButton(
                              text: 'Buat Invoice',
                              icon: Icons.receipt_long_outlined,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _buildGroupedItems(ThemeData theme, ColorScheme colorScheme) {
    // Kelompokkan item berdasarkan request asal agar user tahu item dari req mana.
    final Map<int, List<_ItemState>> grouped = {};
    for (final s in _itemStates) {
      grouped.putIfAbsent(s.requestId, () => []).add(s);
    }

    final widgets = <Widget>[];
    grouped.forEach((reqId, states) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 8),
          child: Text(
            'Request #$reqId',
            style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
        ),
      );
      for (final state in states) {
        widgets.add(_buildItemCard(state, theme, colorScheme));
      }
    });
    return widgets;
  }

  Widget _buildItemCard(
      _ItemState state, ThemeData theme, ColorScheme colorScheme) {
    final detailRequest = state.detailRequest;
    final priceCtrl = state.priceController;
    final qtyCtrl = state.qtyCtrl;

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sectionGap),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: state.selected,
                  onChanged: (val) {
                    setState(() => state.selected = val ?? false);
                  },
                ),
                Expanded(
                  child: Text(
                    detailRequest.productName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (state.selected) ...[
              AppSpacing.gapVerticalSM,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: qtyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Jumlah',
                        suffixText: detailRequest.unitName,
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Expanded(
                    child: TextFormField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Harga Total',
                        prefixText: 'Rp ',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: rupiahInputFormatters,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (_) {
                  final totalPrice = parseAmount(priceCtrl.text) ?? 0;
                  final qty = double.tryParse(qtyCtrl.text) ?? 0;
                  final unitPrice = qty > 0 ? (totalPrice / qty) : 0.0;
                  if (totalPrice <= 0) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calculate_outlined,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Harga Satuan: ${_currencyFormatter.format(unitPrice.round())} / ${detailRequest.unitName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemState {
  final int requestId;
  final DetailRequestItem detailRequest;
  final TextEditingController priceController;
  final TextEditingController qtyCtrl;
  bool selected = true;

  _ItemState({
    required this.requestId,
    required this.detailRequest,
    required this.priceController,
    required this.qtyCtrl,
  });
}
