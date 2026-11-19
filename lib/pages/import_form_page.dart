import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/import_model.dart';
import '../models/procurement_model.dart';
import '../services/import_service.dart';
import '../services/procurement_service.dart';
import '../services/supplier_service.dart';
import '../theme/app_spacing.dart';
import '../utils/country_catalog.dart';
import '../utils/format_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_field.dart';
import '../widgets/supplier_picker_modal.dart';

/// Presisi desimal isian — mengikuti kolom DB (kurs 12,2; qty 16,3;
/// harga valuta 16,4 namun UI 2 digit sesuai kebiasaan harga; tax_rate 6,3;
/// nominal rupiah bulat).
const int _kursDecimals = 2;
const int _qtyDecimals = 3;
const int _priceDecimals = 2;
const int _taxRateDecimals = 3;
const int _foreignDecimals = 2;
const int _rupiahDecimals = 0;

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

/// Cara penetapan nominal satu baris biaya — menentukan field yang aktif:
/// - [estimate] : nominal rupiah langsung (amount_estimate).
/// - [foreign]  : nominal valuta × kurs (amount_foreign).
/// - [taxRate]  : persen dari total nilai barang (tax_rate), kategori pajak.
enum _CostMode { estimate, foreign, taxRate }

/// Form editabel biaya (estimate) dalam proses impor.
class _CostDraft {
  _CostDraft({
    String? name,
    this.stage = 'payment',
    this.category = 'other',
    this.mode = _CostMode.estimate,
    String? amount,
    String? foreignAmount,
    String? taxRate,
  }) {
    if (name != null) nameCtrl.text = name;
    if (amount != null) estimateCtrl.text = amount;
    if (foreignAmount != null) foreignCtrl.text = foreignAmount;
    if (taxRate != null) taxRateCtrl.text = taxRate;
  }

  final nameCtrl = TextEditingController();
  String stage = 'payment';
  String category = 'other';
  _CostMode mode;
  final taxRateCtrl = TextEditingController();
  final foreignCtrl = TextEditingController();
  final estimateCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    taxRateCtrl.dispose();
    foreignCtrl.dispose();
    estimateCtrl.dispose();
  }
}

/// Urutan tahap biaya — sekaligus urutan kelompok di seksi biaya.
const List<String> _stageOrder = [
  'purchase',
  'payment',
  'shipment',
  'customs',
  'arrival',
];

String _stageLabel(String stage) => switch (stage) {
      'purchase' => 'Pembelian',
      'payment' => 'Pembayaran',
      'shipment' => 'Pengiriman',
      'customs' => 'Kepabeanan',
      _ => 'Kedatangan',
    };

IconData _stageIcon(String stage) => switch (stage) {
      'purchase' => Icons.shopping_cart_outlined,
      'payment' => Icons.payments_outlined,
      'shipment' => Icons.directions_boat_outlined,
      'customs' => Icons.gavel_outlined,
      _ => Icons.anchor_outlined,
    };

String _categoryLabel(String category) => switch (category) {
      'bank' => 'Bank',
      'tax' => 'Pajak',
      'logistics' => 'Logistik',
      'goods' => 'Barang',
      'discount' => 'Diskon',
      _ => 'Lainnya',
    };

/// Baris biaya standar impor mete (replika sheet "HPP METE") yang langsung
/// disiapkan saat membuat proses impor baru — menjaga penamaan, tahap &
/// kategori konsisten antar pencatatan. Yang tidak terpakai cukup
/// dibiarkan kosong / dinolkan; biaya di luar daftar ditambah manual.
/// Nilai awal ditulis dalam gaya isian Indonesia (koma desimal).
List<_CostDraft> _defaultCostRows() {
  return [
    _CostDraft(
      name: 'Discounts',
      stage: 'purchase',
      category: 'discount',
    ),
    _CostDraft(
      name: 'Transfer Bank',
      stage: 'payment',
      category: 'bank',
      mode: _CostMode.foreign,
      foreignAmount: '25',
    ),
    _CostDraft(
      name: 'Bank',
      stage: 'payment',
      category: 'bank',
      amount: '35.000',
    ),
    _CostDraft(name: 'Perjalanan', stage: 'payment', category: 'other'),
    _CostDraft(name: 'Unloading', stage: 'arrival', category: 'logistics'),
    _CostDraft(
      name: 'PPH Impor',
      stage: 'customs',
      category: 'tax',
      mode: _CostMode.taxRate,
      taxRate: '2,5',
    ),
    _CostDraft(
      name: 'PPN Impor',
      stage: 'customs',
      category: 'tax',
      mode: _CostMode.taxRate,
      taxRate: '11',
    ),
    _CostDraft(name: 'Handling Koja', stage: 'customs', category: 'logistics'),
    _CostDraft(name: 'D/O 1', stage: 'arrival', category: 'logistics'),
    _CostDraft(name: 'D/O 2', stage: 'arrival', category: 'logistics'),
    _CostDraft(
        name: 'Handling, trucking, SSM',
        stage: 'arrival',
        category: 'logistics'),
    _CostDraft(name: 'Storage', stage: 'arrival', category: 'logistics'),
    _CostDraft(name: 'PNBP', stage: 'customs', category: 'other'),
    _CostDraft(
        name: 'Lift-off Depo SPM', stage: 'arrival', category: 'logistics'),
  ];
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
  final _usdVndRateCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  DateTime _purchaseDate = DateTime.now();

  List<Map<String, dynamic>> _suppliers = [];
  var _products = <ProcurementProduct>[];
  final _items = <_ItemDraft>[_ItemDraft()];
  final _costs = <_CostDraft>[];
  final _collapsedStages = <String>{};
  String _currency = 'USD';
  int? _supplierId;
  String _supplierName = '';
  Map<String, dynamic>? _supplierMeta;
  bool _saving = false;
  bool _loadingMaster = true;
  bool _prefilledFromPrevious = false;

  /// Referensi terkini 1 USD = x VND dari server (untuk prefill kurs
  /// transaksi); null bila belum termuat.
  double? _usdVndRef;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadMaster();
    _loadUsdVndRef();
  }

  /// Referensi kurs USD → VND terkini dari backend terpusat — prefill
  /// kurs transaksi (create saja); best-effort, gagal = isi tangan.
  Future<void> _loadUsdVndRef() async {
    try {
      final rates = await _service.getUsdVndRates();
      if (!mounted) return;
      final latest = rates.latestRate;
      if (latest == null || latest <= 0) return;
      setState(() {
        _usdVndRef = latest;
        if (!_isEdit && _usdVndRateCtrl.text.trim().isEmpty) {
          _usdVndRateCtrl.text = FormatUtils.formatAmount(latest);
        }
      });
    } catch (_) {
      // Referensi best-effort — tetap bisa input manual.
    }
  }

  void _prefill() {
    final e = widget.existing;
    if (e == null) {
      // Proses baru: siapkan baris biaya standar (sheet HPP METE) agar
      // penamaan & kategori seragam; edit memakai data server apa adanya.
      _costs.addAll(_defaultCostRows());
      return;
    }
    _supplierId = e.supplierId;
    _supplierName = e.supplierName;
    _currency = e.currency;
    _kursCtrl.text = e.exchangeRate == 0
        ? ''
        : FormatUtils.formatAmount(e.exchangeRate, decimals: _kursDecimals);
    if (e.usdVndRate != null && e.usdVndRate! > 0) {
      _usdVndRateCtrl.text = FormatUtils.formatAmount(e.usdVndRate!);
    }
    _invoiceCtrl.text = e.invoiceNumber ?? '';
    _purchaseDate = e.purchaseDate ?? DateTime.now();

    _items
      ..clear()
      ..addAll(e.items.map((i) {
        final d = _ItemDraft();
        d.productId = i.productId;
        d.productName = i.productName;
        d.unitName = i.unitName;
        d.qtyCtrl.text =
            FormatUtils.formatAmount(i.quantity, decimals: _qtyDecimals);
        d.priceCtrl.text = FormatUtils.formatAmount(i.unitPriceForeign,
            decimals: _priceDecimals);
        return d;
      }));
    _costs
      ..clear()
      ..addAll(e.costs.where((c) => !c.isDerived).map((c) {
        final d = _CostDraft(
          mode: c.taxRate != null
              ? _CostMode.taxRate
              : (c.isForeignCurrency ? _CostMode.foreign : _CostMode.estimate),
        );
        d.nameCtrl.text = c.name;
        d.stage = c.stage;
        d.category = c.category;
        if (c.taxRate != null) {
          d.taxRateCtrl.text =
              FormatUtils.formatAmount(c.taxRate!, decimals: _taxRateDecimals);
        }
        if (c.amountForeign != null) {
          d.foreignCtrl.text = FormatUtils.formatAmount(c.amountForeign!,
              decimals: _foreignDecimals);
        }
        d.estimateCtrl.text = FormatUtils.formatAmount(c.amountEstimate,
            decimals: _rupiahDecimals);
        return d;
      }));
  }

  Future<ImportPurchase?> _loadCostTemplate() async {
    if (_isEdit) return null;
    try {
      return await _service.getLatestForCostTemplate();
    } catch (_) {
      // Form tetap bisa dipakai dengan template default bila gagal.
      return null;
    }
  }

  String _normalizeCostName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Salin nominal REALISASI biaya non-pajak/non-barang dari impor
  /// terakhir. Produk dan baris pajak (PPh/PPN) sengaja dilewati karena
  /// bergantung pada nilai barang yang baru. Baris custom non-pajak ikut
  /// disalin; baris tanpa realisasi tidak menimpa nilai default template.
  void _applyCostTemplate(ImportPurchase previous) {
    final byName = <String, _CostDraft>{
      for (final draft in _costs)
        _normalizeCostName(draft.nameCtrl.text): draft,
    };
    var applied = 0;

    for (final cost in previous.costs) {
      if (cost.isDerived ||
          cost.category == 'tax' ||
          cost.category == 'goods' ||
          cost.taxRate != null) {
        continue;
      }

      final realized = cost.amountReal ?? 0;
      // Tanpa realisasi: jangan timpa default template (mis. Transfer Bank
      // 25 USD) dan jangan tambah baris custom kosong.
      if (realized == 0) continue;

      final key = _normalizeCostName(cost.name);
      var draft = byName[key];
      if (draft == null) {
        draft = _CostDraft(
          name: cost.name,
          stage: cost.stage,
          category: cost.category,
        );
        _costs.add(draft);
        byName[key] = draft;
      }

      // Realisasi tersimpan dalam rupiah; masukkan sebagai estimasi baru.
      final amount = cost.category == 'discount' ? realized.abs() : realized;
      draft.mode = _CostMode.estimate;
      draft.estimateCtrl.text =
          FormatUtils.formatAmount(amount, decimals: _rupiahDecimals);
      draft.foreignCtrl.clear();
      applied++;
    }

    if (applied > 0) _prefilledFromPrevious = true;
  }

  Future<void> _loadMaster() async {
    try {
      final suppliersFuture = _supplierService.getSuppliers();
      final productsFuture = _procurementService.getProducts();
      final templateFuture = _loadCostTemplate();
      final suppliers = await suppliersFuture;
      final products = await productsFuture;
      final template = await templateFuture;
      if (!mounted) return;
      setState(() {
        // Impor hanya dari supplier luar negeri — domestik tidak ditawarkan.
        _suppliers = suppliers
            .where((s) => s.isForeign)
            .map((s) => <String, dynamic>{
                  'id': s.id,
                  'name': s.name,
                  'address': s.address,
                  'no_telp': s.noTelp,
                  'bank_name': s.bankName,
                  'bank_account_name': s.bankAccountName,
                  'bank_account_no': s.bankAccountNo,
                  'qris': s.qris,
                  'status': s.status,
                  'is_foreign': s.isForeign,
                  'country_code': s.countryCode,
                  'country_name': s.isForeign ? s.countryName : null,
                  'currency': s.currency,
                  'city_name': s.cityName,
                })
            .toList();
        _products = products;
        if (template != null) _applyCostTemplate(template);
        _loadingMaster = false;
        if (_supplierId != null) {
          for (final s in _suppliers) {
            if (s['id'] == _supplierId) {
              _supplierMeta = s;
              break;
            }
          }
        }
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
    _usdVndRateCtrl.dispose();
    _invoiceCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    for (final c in _costs) {
      c.dispose();
    }
    super.dispose();
  }

  double get _kurs => parseAmount(_kursCtrl.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: _isEdit ? 'Edit Proses Impor' : 'Proses Impor Baru',
      isLoading: _loadingMaster,
      bodyPadding: EdgeInsets.zero,
      body: Builder(
        // Konteks dalam body Scaffold: clearance atas (app bar kaca) +
        // bawah (bar aksi simpan, extendBody) dari MediaQuery.
        builder: (bodyContext) => ListView(
          // Geser daftar = tutup keyboard (form panjang; tombol simpan
          // naik mengikuti keyboard via AppPageScaffold).
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: AppSpacing.screenPadding.copyWith(
            top: AppBarInsets.top(bodyContext),
            bottom: MediaQuery.paddingOf(bodyContext).bottom + AppSpacing.md,
          ),
          children: [
            _buildHeaderSection(),
            const SizedBox(height: AppSpacing.sectionGap),
            _buildItemsSection(),
            const SizedBox(height: AppSpacing.sectionGap),
            _buildCostsSection(),
            AppSpacing.gapVerticalXL,
          ],
        ),
      ),
      bottomAction: ModernButton(
        text: _isEdit ? 'Simpan Perubahan' : 'Simpan Proses Impor',
        isLoading: _saving,
        onPressed: _save,
      ),
    );
  }

  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    final meta = _supplierMeta;
    final isForeign = meta?['is_foreign'] == true;
    final metaLine = isForeign
        ? [
            (meta?['country_name'] ?? '').toString(),
            if ((meta?['currency'] ?? '').toString().isNotEmpty)
              'valuta ${meta!['currency']}',
          ].where((s) => s.isNotEmpty).join(' • ')
        : '';

    return FormSectionCard(
      title: 'Informasi Umum',
      subtitle: 'Supplier, tanggal transaksi, no. invoice, valuta & kurs',
      icon: Icons.public_outlined,
      children: [
        // Supplier
        InkWell(
          onTap: _pickSupplier,
          borderRadius: AppSpacing.borderRadiusMD,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Supplier',
              prefixIcon: Icon(Icons.business_outlined),
              suffixIcon: Icon(Icons.chevron_right_rounded),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _supplierName.isEmpty ? 'Pilih supplier…' : _supplierName,
                  style: TextStyle(
                    color: _supplierName.isEmpty
                        ? theme.hintColor
                        : theme.textTheme.bodyLarge?.color,
                  ),
                ),
                if (metaLine.isNotEmpty)
                  Text(
                    metaLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: _pickPurchaseDate,
          borderRadius: AppSpacing.borderRadiusMD,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tanggal Impor',
              prefixIcon: Icon(Icons.event_outlined),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              DateFormat('d MMMM yyyy', 'id_ID').format(_purchaseDate),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
        ModernTextField(
          labelText: 'No. Invoice',
          controller: _invoiceCtrl,
          prefixIcon: Icons.receipt_long_outlined,
          textCapitalization: TextCapitalization.characters,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ModernDropdown<String>(
                value: _currency,
                hint: 'Valuta',
                labelText: 'Valuta Beli',
                prefixIcon: const Icon(Icons.currency_exchange_outlined),
                items: CurrencyCatalog.withCode(_currency),
                getLabel: (v) => v,
                onChanged: (v) => setState(() => _currency = v ?? 'USD'),
              ),
            ),
            AppSpacing.gapHorizontalMD,
            Expanded(
              child: ModernTextField(
                labelText: 'Kurs Rp / $_currency',
                controller: _kursCtrl,
                prefixIcon: Icons.swap_horiz_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [
                  CurrencyInputFormatter(decimals: _kursDecimals),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        // Kurs USD → VND melekat pada transaksi ini — dipakai analisa
        // trend harga kontrak lintas valuta; prefill dari referensi
        // terkini (server), boleh diubah sesuai kontrak.
        ModernTextField(
          labelText: 'Kurs 1 USD = x VND',
          controller: _usdVndRateCtrl,
          prefixIcon: Icons.currency_exchange_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: const [CurrencyInputFormatter()],
          onChanged: (_) => setState(() {}),
        ),
        Text(
          _usdVndRef == null
              ? 'Kurs transaksi untuk analisa harga lintas USD ↔ VND.'
              : 'Referensi terkini: ${FormatUtils.formatAmount(_usdVndRef!)} '
                  '— terisi otomatis, ubah bila kontrak memakai kurs lain.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _pickSupplier() async {
    if (_suppliers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tidak ada supplier luar negeri tersedia.')),
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
        _supplierMeta = result;
        // Valuta transaksi supplier (bila diisi di master) jadi default
        // valuta beli — tetap bisa diganti di dropdown.
        final currency = (result['currency'] ?? '').toString();
        if (currency.isNotEmpty) _currency = currency;
      });
    }
  }

  Widget _buildItemsSection() {
    return FormSectionCard(
      title: 'Produk Diimpor (${_items.length})',
      subtitle: 'Pilih produk, isi jumlah & harga valuta — subtotal rupiah '
          'mengikuti kurs di atas',
      icon: Icons.inventory_2_outlined,
      trailing: FormAddButton(
        label: 'Tambah',
        onPressed: () => setState(() => _items.add(_ItemDraft())),
      ),
      child: _items.isEmpty
          ? _emptyHint(
              icon: Icons.inventory_2_outlined,
              title: 'Belum ada produk',
              message: 'Tekan "Tambah" untuk memilih produk yang diimpor.',
            )
          : Column(
              children: [
                for (var i = 0; i < _items.length; i++) _buildItemCard(i),
              ],
            ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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

    final qty = parseAmount(item.qtyCtrl.text) ?? 0;
    final price = parseAmount(item.priceCtrl.text) ?? 0;
    final unit = item.unitName.trim();
    final breakdown = qty > 0 && price >= 0
        ? '${FormatUtils.formatAmount(qty, decimals: _qtyDecimals)} '
            '${unit.isEmpty ? 'unit' : unit} × '
            '${FormatUtils.formatAmount(price, decimals: _priceDecimals)} '
            '$_currency'
        : 'Isi jumlah & harga satuan';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ModernDropdown<ProcurementProduct>(
                  value: selectedProduct,
                  hint: item.productName.isEmpty
                      ? 'Pilih produk…'
                      : item.productName,
                  labelText: 'Produk',
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
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: cs.error,
                tooltip: 'Hapus produk',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => setState(() {
                  item.dispose();
                  _items.removeAt(index);
                }),
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: ModernTextField(
                  labelText: unit.isEmpty ? 'Jumlah' : 'Jumlah ($unit)',
                  controller: item.qtyCtrl,
                  prefixIcon: Icons.scale_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [
                    CurrencyInputFormatter(decimals: _qtyDecimals),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                flex: 3,
                child: ModernTextField(
                  labelText: 'Harga satuan ($_currency)',
                  controller: item.priceCtrl,
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [
                    CurrencyInputFormatter(decimals: _priceDecimals),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  breakdown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Subtotal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _itemSubtotal(item),
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Subtotal rupiah live satu item = jumlah × harga valuta × kurs.
  String _itemSubtotal(_ItemDraft item) {
    final qty = parseAmount(item.qtyCtrl.text) ?? 0;
    final price = parseAmount(item.priceCtrl.text) ?? 0;
    return FormatUtils.formatRupiah(qty * price * _kurs);
  }

  /* --------------------------------------------------------------- COSTS */

  /// Nilai rupiah satu baris biaya sesuai jenis nominalnya.
  double _costRupiah(_CostDraft cost, double kurs, double goodsTotal) {
    final value = switch (cost.mode) {
      _CostMode.estimate => parseAmount(cost.estimateCtrl.text) ?? 0,
      _CostMode.foreign => (parseAmount(cost.foreignCtrl.text) ?? 0) * kurs,
      _CostMode.taxRate =>
        (parseAmount(cost.taxRateCtrl.text) ?? 0) / 100 * goodsTotal,
    };
    // Diskon mengurangi total, bukan menambah.
    return cost.category == 'discount' ? -value.abs() : value;
  }

  /// Estimasi live dari isian saat ini: (nilai barang, total biaya).
  (double, double) _estimateTotals() {
    final kurs = _kurs;

    var goodsTotal = 0.0;
    for (final item in _items) {
      final qty = parseAmount(item.qtyCtrl.text) ?? 0;
      final price = parseAmount(item.priceCtrl.text) ?? 0;
      goodsTotal += qty * price * kurs;
    }

    var costTotal = 0.0;
    for (final cost in _costs) {
      costTotal += _costRupiah(cost, kurs, goodsTotal);
    }
    return (goodsTotal, costTotal);
  }

  Widget _buildCostsSection() {
    final (goodsTotal, _) = _estimateTotals();
    final kurs = _kurs;

    return FormSectionCard(
      title: 'Biaya-biaya (${_costs.length})',
      subtitle: _prefilledFromPrevious
          ? 'Nominal realisasi impor terakhir — produk & PPh/PPN tidak '
              'disalin. '
              'Pajak persen tetap dihitung dari nilai barang.'
          : 'Dikelompokkan per tahap — ketuk + pada tahap untuk menambah '
              'baris, ketuk judul untuk melipat. Pajak persen dihitung dari '
              'nilai barang.',
      icon: Icons.request_quote_outlined,
      child: Column(
        children: [
          for (final stage in _stageOrder)
            ..._buildStageGroup(stage, kurs, goodsTotal),
          if (_costs.isNotEmpty) ...[
            AppSpacing.gapVerticalXS,
            _buildTotalStrip(),
          ],
        ],
      ),
    );
  }

  void _addCostToStage(String stage) {
    setState(() {
      _costs.add(_CostDraft(stage: stage));
      _collapsedStages.remove(stage);
    });
  }

  List<Widget> _buildStageGroup(String stage, double kurs, double goodsTotal) {
    final indices = <int>[
      for (var i = 0; i < _costs.length; i++)
        if (_costs[i].stage == stage) i,
    ];
    if (indices.isEmpty) {
      return [_buildEmptyStageRow(stage)];
    }

    final subtotal = indices.fold<double>(
      0,
      (sum, i) => sum + _costRupiah(_costs[i], kurs, goodsTotal),
    );
    final collapsed = _collapsedStages.contains(stage);

    return [
      _buildStageHeader(
        stage,
        count: indices.length,
        subtotal: subtotal,
        collapsed: collapsed,
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: collapsed
            ? const SizedBox(width: double.infinity)
            : Column(
                children: [
                  for (final i in indices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _buildCostCard(i, kurs, goodsTotal),
                    ),
                ],
              ),
      ),
    ];
  }

  /// Tahap tanpa biaya tetap tampil sebagai satu baris ringkas — menjadi
  /// pintu masuk penambahan tanpa dropdown "Tahap" berulang di tiap kartu.
  Widget _buildEmptyStageRow(String stage) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: AppSpacing.borderRadiusSM,
      onTap: () => _addCostToStage(stage),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 2, 6),
        child: Row(
          children: [
            Icon(
              _stageIcon(stage),
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            AppSpacing.gapHorizontalSM,
            Expanded(
              child: Text(
                _stageLabel(stage),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              'Tambah',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.add_rounded, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }

  /// Judul kelompok tahap: ikon tahap, nama + jumlah baris, subtotal rupiah
  /// live di kanan, tombol tambah baris, dan chevron lipat.
  Widget _buildStageHeader(
    String stage, {
    required int count,
    required double subtotal,
    required bool collapsed,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: AppSpacing.borderRadiusSM,
      onTap: () => setState(() {
        if (collapsed) {
          _collapsedStages.remove(stage);
        } else {
          _collapsedStages.add(stage);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 2, 4),
        child: Row(
          children: [
            Icon(_stageIcon(stage), size: 16, color: cs.primary),
            AppSpacing.gapHorizontalSM,
            Text(
              _stageLabel(stage),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapHorizontalSM,
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    FormatUtils.formatRupiah(subtotal),
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: subtotal > 0 ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 18),
              tooltip: 'Tambah biaya ${_stageLabel(stage)}',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _addCostToStage(stage),
            ),
            Icon(
              collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostCard(int index, double kurs, double goodsTotal) {
    final cost = _costs[index];
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final derived = cost.mode == _CostMode.estimate
        ? null
        : _costRupiah(cost, kurs, goodsTotal);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  labelText: 'Nama biaya',
                  controller: cost.nameCtrl,
                  prefixIcon: Icons.edit_note,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Pindah tahap',
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                onSelected: (value) => setState(() {
                  cost.stage = value;
                  _collapsedStages.remove(value);
                }),
                itemBuilder: (_) => [
                  for (final stage in _stageOrder)
                    if (stage != cost.stage)
                      PopupMenuItem<String>(
                        value: stage,
                        child: Row(
                          children: [
                            Icon(_stageIcon(stage), size: 16),
                            const SizedBox(width: 8),
                            Text('Pindah ke ${_stageLabel(stage)}'),
                          ],
                        ),
                      ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: cs.error,
                tooltip: 'Hapus biaya',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  cost.dispose();
                  _costs.removeAt(index);
                }),
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          // Jenis nominal + isian nilainya sebaris agar baris biaya ringkas.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: ModernDropdown<_CostMode>(
                  value: cost.mode,
                  hint: 'Jenis',
                  labelText: 'Jenis',
                  items: _CostMode.values,
                  getLabel: (m) => switch (m) {
                    _CostMode.estimate => 'Rupiah',
                    _CostMode.foreign => 'Valuta × kurs',
                    _CostMode.taxRate => '% nilai barang',
                  },
                  getSubtitle: (m) => switch (m) {
                    _CostMode.estimate => 'Nominal rupiah langsung (estimasi)',
                    _CostMode.foreign =>
                      'Nominal $_currency dikali kurs saat ini',
                    _CostMode.taxRate =>
                      'Persen dari total nilai barang — kategori pajak',
                  },
                  onChanged: (m) => setState(() {
                    cost.mode = m ?? _CostMode.estimate;
                    // Pajak persen secara semantik adalah kategori tax.
                    if (cost.mode == _CostMode.taxRate) cost.category = 'tax';
                  }),
                ),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                flex: 3,
                child: switch (cost.mode) {
                  _CostMode.taxRate => ModernTextField(
                      labelText: 'Persen (%)',
                      controller: cost.taxRateCtrl,
                      prefixIcon: Icons.percent,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [
                        CurrencyInputFormatter(decimals: _taxRateDecimals),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  _CostMode.foreign => ModernTextField(
                      labelText: 'Nominal $_currency',
                      controller: cost.foreignCtrl,
                      prefixIcon: Icons.attach_money,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [
                        CurrencyInputFormatter(decimals: _foreignDecimals),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  _CostMode.estimate => ModernTextField(
                      labelText: 'Estimasi (Rp)',
                      controller: cost.estimateCtrl,
                      prefixIcon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [
                        CurrencyInputFormatter(decimals: _rupiahDecimals),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                },
              ),
            ],
          ),
          if (derived != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '≈ ${FormatUtils.formatRupiah(derived)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: derived > 0 ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          AppSpacing.gapVerticalSM,
          ModernDropdown<String>(
            value: cost.category,
            hint: 'Kategori',
            labelText: 'Kategori',
            items: const [
              'goods',
              'bank',
              'tax',
              'logistics',
              'other',
              'discount'
            ],
            getLabel: _categoryLabel,
            onChanged: (v) => setState(() => cost.category = v ?? 'other'),
          ),
        ],
      ),
    );
  }

  /// Strip total di ujung seksi biaya: nilai utama menyusut (FittedBox)
  /// alih-alih terpotong saat mencapai ratusan juta / miliar; rincian
  /// barang vs biaya dipecah dua kolom agar tetap terbaca penuh.
  Widget _buildTotalStrip() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (goodsTotal, costTotal) = _estimateTotals();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 18, color: cs.primary),
              AppSpacing.gapHorizontalSM,
              Text(
                'Total Estimasi',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      FormatUtils.formatRupiah(goodsTotal + costTotal),
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 26),
              Expanded(
                child: _totalPart(theme, cs, 'Nilai barang', goodsTotal),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                child: _totalPart(theme, cs, 'Biaya-biaya', costTotal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalPart(ThemeData theme, ColorScheme cs, String label, double v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            FormatUtils.formatRupiah(v),
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyHint({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
          ),
          AppSpacing.gapVerticalSM,
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapVerticalXS,
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      showErrorDialog(context, 'Supplier wajib dipilih.');
      return;
    }
    final kurs = parseAmount(_kursCtrl.text);
    if (kurs == null || kurs <= 0) {
      showErrorDialog(context, 'Kurs harus berupa angka lebih dari 0.');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final item in _items) {
      final qty = parseAmount(item.qtyCtrl.text);
      final price = parseAmount(item.priceCtrl.text);
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
        'tax_rate': cost.mode == _CostMode.taxRate
            ? (parseAmount(cost.taxRateCtrl.text) ?? 0)
            : null,
        'is_foreign_currency': cost.mode == _CostMode.foreign,
        'amount_foreign': cost.mode == _CostMode.foreign
            ? (parseAmount(cost.foreignCtrl.text) ?? 0)
            : null,
        'amount_estimate': cost.mode == _CostMode.estimate
            ? (parseAmount(cost.estimateCtrl.text) ?? 0)
            : 0,
      });
    }

    final invoice = _invoiceCtrl.text.trim();
    final payload = {
      'supplier_id': _supplierId,
      'currency': _currency,
      'exchange_rate': kurs,
      'usd_vnd_rate': parseAmount(_usdVndRateCtrl.text),
      'invoice_number': invoice.isEmpty ? null : invoice,
      'purchase_date': DateFormat('yyyy-MM-dd').format(_purchaseDate),
      'items': items,
      'costs': costs,
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _service.updateImport(widget.existing!.id, payload);
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final createdId = await _service.createImport(payload);
        if (!mounted) return;
        // List menampilkan konfirmasi; pengguna tetap di list dan bisa
        // membuka detail/realisasi saat siap.
        Navigator.pop(context, createdId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
