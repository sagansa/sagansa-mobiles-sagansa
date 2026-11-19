import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/procurement_model.dart';
import '../../services/image_service.dart';
import '../../services/procurement_service.dart';
import '../../services/supplier_service.dart';
import '../../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/modern_button.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/supplier_payment_info_card.dart';
import '../widgets/supplier_picker_modal.dart';

class EditInvoicePage extends StatefulWidget {
  final InvoicePurchase invoice;

  const EditInvoicePage({super.key, required this.invoice});

  @override
  State<EditInvoicePage> createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage> {
  final ProcurementService _procurementService = ProcurementService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  bool _isSubmitting = false;
  bool _isAdmin = false;

  int? _selectedSupplierId;
  String _selectedSupplierName = '';
  Map<String, dynamic>? _selectedSupplier;
  int _paymentTypeId = 2;
  final _taxesController = TextEditingController();
  final _discountsController = TextEditingController();
  final _notesController = TextEditingController();
  List<Map<String, dynamic>> _itemStates = [];
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _selectedSupplierId = widget.invoice.supplierId;
    _selectedSupplierName = widget.invoice.supplierName ?? '';
    _paymentTypeId = widget.invoice.paymentTypeId ?? 2;
    _taxesController.text = FormatUtils.formatAmount(widget.invoice.taxes);
    _discountsController.text =
        FormatUtils.formatAmount(widget.invoice.discounts);
    _notesController.text = widget.invoice.notes ?? '';
    _itemStates = widget.invoice.detailInvoices.map((item) {
      return {
        'detailInvoice': item,
        'priceController': TextEditingController(
          text: FormatUtils.formatAmount(item.subtotalInvoice),
        ),
        'qtyController': TextEditingController(
          text: item.quantityProduct.toStringAsFixed(
            item.quantityProduct == item.quantityProduct.roundToDouble()
                ? 0
                : 2,
          ),
        ),
      };
    }).toList();
    _loadSupplierPaymentInfo();
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
  }

  /// Pre-populate [_selectedSupplier] dari supplier invoice saat ini agar
  /// kartu [SupplierPaymentInfoCard] langsung tampil (rekening & QRIS).
  Future<void> _loadSupplierPaymentInfo() async {
    final supplierId = widget.invoice.supplierId;
    if (supplierId == null) return;
    try {
      final supplier = await SupplierService().getSupplier(supplierId);
      if (!mounted) return;
      setState(() {
        _selectedSupplier = {
          'id': supplier.id,
          'name': supplier.name,
          'address': supplier.address,
          'no_telp': supplier.noTelp,
          'bank_name': supplier.bankName,
          'bank_account_name': supplier.bankAccountName,
          'bank_account_no': supplier.bankAccountNo,
          'qris': supplier.qris,
        };
      });
    } catch (_) {
      // Rekening gagal dimuat — kartu tetap muncul saat user memilih supplier.
    }
  }

  @override
  void dispose() {
    _taxesController.dispose();
    _discountsController.dispose();
    _notesController.dispose();
    for (var state in _itemStates) {
      (state['priceController'] as TextEditingController).dispose();
      (state['qtyController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  int get _totalPrice {
    int total = 0;
    for (var state in _itemStates) {
      final price = parseAmountInt(
          (state['priceController'] as TextEditingController).text);
      total += price;
    }
    final taxes = parseAmountInt(_taxesController.text);
    final discounts = parseAmountInt(_discountsController.text);
    return total + taxes - discounts;
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

    final hasExistingImage =
        widget.invoice.imageUrl != null && widget.invoice.imageUrl!.isNotEmpty;
    if (!_isAdmin && _imageFile == null && !hasExistingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto invoice wajib diunggah.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updated = await _procurementService.updateInvoice(
        widget.invoice.id,
        supplierId: _selectedSupplierId,
        paymentTypeId: _paymentTypeId,
        taxes: parseAmountInt(_taxesController.text),
        discounts: parseAmountInt(_discountsController.text),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        image: _imageFile,
        items: _itemStates.map((s) {
          final detail = s['detailInvoice'] as DetailInvoiceItem;
          final total = parseAmount(
                  (s['priceController'] as TextEditingController).text) ??
              0;
          final qty = double.tryParse(
                  (s['qtyController'] as TextEditingController).text) ??
              0;
          return {
            'detail_invoice_id': detail.id,
            'subtotal_invoice': total.round(),
            'quantity': qty.toInt(),
          };
        }).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice berhasil diperbarui.')),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui invoice: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Invoice'),
      ),
      body: _isSubmitting
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
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: _selectedSupplierName.isEmpty
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
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
                      AppSpacing.gapVerticalLG,
                      DropdownButtonFormField<int>(
                        initialValue: _paymentTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Tipe Pembayaran *',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Transfer')),
                          DropdownMenuItem(value: 2, child: Text('Tunai')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentTypeId = val);
                        },
                      ),
                      AppSpacing.gapVerticalLG,
                      Text(
                        'Item & Harga',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: AppSpacing.sectionGap),
                      ..._itemStates.map((state) {
                        final detail =
                            state['detailInvoice'] as DetailInvoiceItem;
                        final priceCtrl =
                            state['priceController'] as TextEditingController;
                        final qtyCtrl =
                            state['qtyController'] as TextEditingController;

                        return Card(
                          margin:
                              EdgeInsets.only(bottom: AppSpacing.sectionGap),
                          child: Padding(
                            padding: AppSpacing.cardPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.productName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                AppSpacing.gapVerticalSM,
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: qtyCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Jumlah',
                                          suffixText: detail.unitName,
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    SizedBox(
                                        width: AppSpacing.sm + AppSpacing.xs),
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
                                    final totalPrice =
                                        parseAmount(priceCtrl.text) ?? 0;
                                    final qty =
                                        double.tryParse(qtyCtrl.text) ?? 0;
                                    final unitPrice =
                                        qty > 0 ? (totalPrice / qty) : 0.0;
                                    if (totalPrice <= 0) {
                                      return const SizedBox.shrink();
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calculate_outlined,
                                            size: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Harga Satuan: ${_currencyFormatter.format(unitPrice.round())} / ${detail.unitName}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      AppSpacing.gapVerticalMD,
                      TextFormField(
                        controller: _taxesController,
                        decoration: const InputDecoration(
                          labelText: 'Pajak',
                          prefixText: 'Rp ',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: rupiahInputFormatters,
                        onChanged: (_) => setState(() {}),
                      ),
                      AppSpacing.gapVerticalSM,
                      TextFormField(
                        controller: _discountsController,
                        decoration: const InputDecoration(
                          labelText: 'Diskon',
                          prefixText: 'Rp ',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: rupiahInputFormatters,
                        onChanged: (_) => setState(() {}),
                      ),
                      AppSpacing.gapVerticalSM,

                      // Bukti/Foto Invoice
                      Text(
                        _isAdmin
                            ? 'Bukti/Foto Invoice'
                            : 'Bukti/Foto Invoice (Wajib)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.invoice.imageUrl != null &&
                          _imageFile == null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMD),
                              child: Image.network(
                                widget.invoice.imageUrl!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  child: const Center(
                                      child: Icon(Icons.broken_image_rounded,
                                          size: 48)),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Foto Saat Ini',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_imageFile != null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMD),
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
                      AppSpacing.gapVerticalSM,

                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Catatan',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                SafeBottomBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                          Text(
                            'Rp ${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.')}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      AppSpacing.gapVerticalSM,
                      ModernButton(
                        text: 'Simpan',
                        icon: Icons.save_outlined,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
