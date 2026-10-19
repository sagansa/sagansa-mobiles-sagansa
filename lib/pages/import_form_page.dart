import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/import_model.dart';
import '../models/procurement_model.dart';
import '../services/import_service.dart';
import '../services/procurement_service.dart';
import '../services/supplier_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_field.dart';
import '../widgets/section_card.dart';
import '../widgets/supplier_picker_modal.dart';

/// Form editabel item produk dalam proses impor.
class _ItemDraft {
  _ItemDraft();

  int? productId;
  String productName = '';
  String unitName = '';
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// Form editabel biaya (estimate) dalam proses impor.
class _CostDraft {
  _CostDraft();

  final nameCtrl = TextEditingController();
  String stage = 'payment';
  String category = 'other';
  bool isTaxRate = false;
  final taxRateCtrl = TextEditingController();
  bool isForeign = false;
  final foreignCtrl = TextEditingController();
  final estimateCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    taxRateCtrl.dispose();
    foreignCtrl.dispose();
    estimateCtrl.dispose();
  }
}

/// Buat proses impor baru (draft) atau edit yang belum final.
///
/// Edit hanya mengirim ulang items/costs penuh (full-replace backend) —
/// items hanya boleh diganti sebelum tahap receiving.
class ImportFormPage extends StatefulWidget {
  final ImportPurchase? existing;

  const ImportFormPage({super.key, this.existing});

  @override
  State<ImportFormPage> createState() => _ImportFormPageState();
}

class _ImportFormPageState extends State<ImportFormPage> {
  final ImportService _service = ImportService();
  final SupplierService _supplierService = SupplierService();
  final ProcurementService _procurementService = ProcurementService();

  final _kursCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<dynamic> _suppliers = [];
  var _products = <ProcurementProduct>[];
  final _items = <_ItemDraft>[_ItemDraft()];
  final _costs = <_CostDraft>[];
  String _currency = 'USD';
  int? _supplierId;
  String _supplierName = '';
  bool _saving = false;
  bool _loadingMaster = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadMaster();
  }

  void _prefill() {
    final e = widget.existing;
    if (e == null) return;
    _supplierId = e.supplierId;
    _supplierName = e.supplierName;
    _currency = e.currency;
    _kursCtrl.text = e.exchangeRate == 0 ? '' : e.exchangeRate.toString();
    _notesCtrl.text = e.notes ?? '';

    _items
      ..clear()
      ..addAll(e.items.map((i) {
        final d = _ItemDraft();
        d.productId = i.productId;
        d.productName = i.productName;
        d.unitName = i.unitName;
        d.qtyCtrl.text = i.quantity.toString();
        d.priceCtrl.text = i.unitPriceForeign.toString();
        return d;
      }));
    _costs
      ..clear()
      ..addAll(e.costs.map((c) {
        final d = _CostDraft();
        d.nameCtrl.text = c.name;
        d.stage = c.stage;
        d.category = c.category;
        d.isTaxRate = c.taxRate != null;
        if (c.taxRate != null) d.taxRateCtrl.text = c.taxRate.toString();
        d.isForeign = c.isForeignCurrency;
        if (c.amountForeign != null) {
          d.foreignCtrl.text = c.amountForeign.toString();
        }
        d.estimateCtrl.text = c.amountEstimate.toString();
        return d;
      }));
  }

  Future<void> _loadMaster() async {
    try {
      final suppliers = await _supplierService.getSuppliers();
      final products = await _procurementService.getProducts();
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'address': s.address,
                  'no_telp': s.noTelp,
                  'bank_name': s.bankName,
                  'bank_account_name': s.bankAccountName,
                  'bank_account_no': s.bankAccountNo,
                })
            .toList();
        _products = products;
        _loadingMaster = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMaster = false);
      showErrorDialog(context, 'Gagal memuat master data: $e');
    }
  }

  @override
  void dispose() {
    _kursCtrl.dispose();
    _notesCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    for (final c in _costs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: _isEdit ? 'Edit Proses Impor' : 'Proses Impor Baru',
      isLoading: _loadingMaster,
      body: ListView(
        children: [
          _buildHeaderSection(),
          AppSpacing.gapVerticalMD,
          _buildItemsSection(),
          AppSpacing.gapVerticalMD,
          _buildCostsSection(),
          AppSpacing.gapVerticalXL,
        ],
      ),
      bottomAction: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Draft'),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SectionCard(
      title: 'Informasi Umum',
      icon: Icons.public_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supplier
          InkWell(
            onTap: _pickSupplier,
            borderRadius: AppSpacing.borderRadiusMD,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Supplier (luar negeri)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              child: Text(
                _supplierName.isEmpty ? 'Pilih supplier…' : _supplierName,
                style: TextStyle(
                  color: _supplierName.isEmpty
                      ? Theme.of(context).hintColor
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
          AppSpacing.gapVerticalMD,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ModernDropdown<String>(
                  value: _currency,
                  hint: 'Valuta',
                  labelText: 'Valuta Beli',
                  prefixIcon: const Icon(Icons.currency_exchange_outlined),
                  items: const ['USD', 'EUR', 'AUD', 'SGD', 'MYR', 'CNY'],
                  getLabel: (v) => v,
                  onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                ),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: ModernTextField(
                  labelText: 'Kurs ke Rupiah',
                  controller: _kursCtrl,
                  prefixIcon: Icons.format_list_numbered,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalMD,
          ModernTextField(
            labelText: 'Catatan (opsional)',
            controller: _notesCtrl,
            prefixIcon: Icons.notes_outlined,
          ),
        ],
      ),
    );
  }

  Future<void> _pickSupplier() async {
    if (_suppliers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada supplier tersedia.')),
      );
      return;
    }
    final result = await SupplierPickerModal.show(
      context: context,
      suppliers: _suppliers,
      selectedSupplierId: _supplierId,
    );
    if (result != null) {
      setState(() {
        _supplierId = result['id'] as int;
        _supplierName = result['name'].toString();
      });
    }
  }

  Widget _buildItemsSection() {
    return SectionCard(
      title: 'Produk Diimpor',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) AppSpacing.gapVerticalMD,
            _buildItemRow(i),
          ],
          AppSpacing.gapVerticalMD,
          OutlinedButton.icon(
            onPressed: () => setState(() => _items.add(_ItemDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Produk'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];

    // Produk terpilih (null bila belum dipilih / hasil prefill tak ada di
    // daftar — mis. produk dihapus; tampilan tetap aman).
    ProcurementProduct? selectedProduct;
    if (item.productId != null) {
      for (final p in _products) {
        if (p.id == item.productId) {
          selectedProduct = p;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ModernDropdown<ProcurementProduct>(
                value: selectedProduct,
                hint: item.productName.isEmpty
                    ? 'Pilih produk…'
                    : item.productName,
                labelText: 'Produk (${index + 1})',
                prefixIcon: const Icon(Icons.category_outlined),
                items: _products,
                getLabel: (p) => p.name,
                getSubtitle: (p) =>
                    p.unitName.isEmpty ? '' : 'Satuan: ${p.unitName}',
                searchable: true,
                onChanged: (p) => setState(() {
                  item.productId = p?.id;
                  item.productName = p?.name ?? '';
                  item.unitName = p?.unitName ?? '';
                }),
              ),
            ),
            if (_items.length > 1) ...[
              AppSpacing.gapHorizontalSM,
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Hapus item',
                onPressed: () => setState(() {
                  item.dispose();
                  _items.removeAt(index);
                }),
              ),
            ],
          ],
        ),
        AppSpacing.gapVerticalSM,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ModernTextField(
                labelText: 'Jumlah (kg)',
                controller: item.qtyCtrl,
                prefixIcon: Icons.scale_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ),
            AppSpacing.gapHorizontalMD,
            Expanded(
              child: ModernTextField(
                labelText: 'Harga satuan ($_currency)',
                controller: item.priceCtrl,
                prefixIcon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCostsSection() {
    return SectionCard(
      title: 'Biaya-biaya (Estimasi)',
      icon: Icons.request_quote_outlined,
      child: Column(
        children: [
          Text(
            'Transfer bank, fee, PPh impor, handling pelabuhan, storage, dll. '
            'Pajak dengan persen (mis. PPh 2,5 / 11) dihitung otomatis dari nilai barang.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          AppSpacing.gapVerticalMD,
          for (var i = 0; i < _costs.length; i++) ...[
            if (i > 0) AppSpacing.gapVerticalMD,
            _buildCostRow(i),
          ],
          AppSpacing.gapVerticalMD,
          OutlinedButton.icon(
            onPressed: () => setState(() => _costs.add(_CostDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Biaya'),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(int index) {
    final cost = _costs[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ModernTextField(
                labelText: 'Nama biaya',
                controller: cost.nameCtrl,
                prefixIcon: Icons.edit_note,
              ),
            ),
            if (_costs.isNotEmpty) ...[
              AppSpacing.gapHorizontalSM,
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Hapus biaya',
                onPressed: () => setState(() {
                  cost.dispose();
                  _costs.removeAt(index);
                }),
              ),
            ],
          ],
        ),
        AppSpacing.gapVerticalSM,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ModernDropdown<String>(
                value: cost.category,
                hint: 'Kategori',
                labelText: 'Kategori',
                items: const ['goods', 'bank', 'tax', 'logistics', 'other'],
                getLabel: (v) => switch (v) {
                  'bank' => 'Bank',
                  'tax' => 'Pajak',
                  'logistics' => 'Logistik',
                  'goods' => 'Barang',
                  _ => 'Lainnya',
                },
                onChanged: (v) =>
                    setState(() => cost.category = v ?? 'other'),
              ),
            ),
            AppSpacing.gapHorizontalMD,
            Expanded(
              child: ModernDropdown<String>(
                value: cost.stage,
                hint: 'Tahap biaya',
                labelText: 'Tahap',
                items: const [
                  'purchase',
                  'payment',
                  'shipment',
                  'customs',
                  'arrival'
                ],
                getLabel: (v) => switch (v) {
                  'purchase' => 'Pembelian',
                  'payment' => 'Pembayaran',
                  'shipment' => 'Pengiriman',
                  'customs' => 'Kepabeanan',
                  _ => 'Kedatangan',
                },
                onChanged: (v) =>
                    setState(() => cost.stage = v ?? 'payment'),
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalSM,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Pajak berbasis % nilai barang'),
          value: cost.isTaxRate,
          onChanged: (v) => setState(() => cost.isTaxRate = v),
        ),
        if (cost.isTaxRate)
          ModernTextField(
            labelText: 'Persen pajak (mis. 2.5 atau 11)',
            controller: cost.taxRateCtrl,
            prefixIcon: Icons.percent,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          )
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('Nominal valuta asing ($_currency)'),
            value: cost.isForeign,
            onChanged: (v) => setState(() => cost.isForeign = v),
          ),
          if (cost.isForeign)
            ModernTextField(
              labelText: 'Nominal valuta (mis. 25)',
              controller: cost.foreignCtrl,
              prefixIcon: Icons.attach_money,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            )
          else
            ModernTextField(
              labelText: 'Estimasi (Rp)',
              controller: cost.estimateCtrl,
              prefixIcon: Icons.payments_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      showErrorDialog(context, 'Supplier wajib dipilih.');
      return;
    }
    final kurs = double.tryParse(_kursCtrl.text);
    if (kurs == null || kurs <= 0) {
      showErrorDialog(context, 'Kurs harus berupa angka lebih dari 0.');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final item in _items) {
      final qty = double.tryParse(item.qtyCtrl.text);
      final price = double.tryParse(item.priceCtrl.text);
      if (item.productId == null || qty == null || qty <= 0 || price == null) {
        showErrorDialog(context,
            'Semua baris produk wajib: produk terpilih, jumlah > 0, harga terisi.');
        return;
      }
      items.add({
        'product_id': item.productId,
        'quantity': qty,
        'unit_price_foreign': price,
      });
    }
    if (items.isEmpty) {
      showErrorDialog(context, 'Minimal 1 produk.');
      return;
    }

    final costs = <Map<String, dynamic>>[];
    for (final cost in _costs) {
      final name = cost.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      costs.add({
        'stage': cost.stage,
        'name': name,
        'category': cost.category,
        'tax_rate': cost.isTaxRate
            ? (double.tryParse(cost.taxRateCtrl.text) ?? 0)
            : null,
        'is_foreign_currency': cost.isForeign,
        'amount_foreign': cost.isForeign
            ? (double.tryParse(cost.foreignCtrl.text) ?? 0)
            : null,
        'amount_estimate':
            double.tryParse(cost.estimateCtrl.text) ?? 0,
      });
    }

    final payload = {
      'supplier_id': _supplierId,
      'currency': _currency,
      'exchange_rate': kurs,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      'items': items,
      'costs': costs,
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _service.updateImport(widget.existing!.id, payload);
      } else {
        await _service.createImport(payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
