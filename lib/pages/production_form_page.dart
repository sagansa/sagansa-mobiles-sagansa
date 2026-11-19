import 'package:flutter/material.dart';

import '../models/production_model.dart';
import '../models/store_model.dart';
import '../services/presence_service.dart';
import '../services/production_service.dart';
import '../services/recipe_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/safe_bottom_bar.dart';

/// Form create produksi.
///
/// Workflow:
///   1. User pilih toko + tanggal + (opsional) resep dari master.
///   2. User WAJIB memilih minimal satu bahan baku dari detail invoice
///      pembelian yang belum terpakai (definisi produksi — sama dengan
///      admin ProductionMainFroms: bahan utama selalu dari invoice,
///      detail invoice berstatus '1', dan otomatis terkonsumsi '2'
///      setelah produksi dibuat).
///   3. Submit → backend create production + auto-prefill items dari resep
///      + item bahan baku dari invoice.
///   4. Setelah create, user lanjut ke ProductionDetailPage untuk atur qty
///      item (override default resep) & apply stok.
///
/// Pilih resep opsional — produksi tanpa resep berarti output akan diinput
/// manual dari detail page; bahan baku dari invoice tetap wajib.
class ProductionFormPage extends StatefulWidget {
  const ProductionFormPage({super.key});

  @override
  State<ProductionFormPage> createState() => _ProductionFormPageState();
}

class _ProductionFormPageState extends State<ProductionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ProductionService _prodService = ProductionService();
  final RecipeService _recipeService = RecipeService();

  final List<StoreModel> _stores = [];
  final List<Recipe> _recipes = [];

  int? _storeId;
  DateTime _date = DateTime.now();
  Recipe? _selectedRecipe;
  final _notesCtrl = TextEditingController();
  final String _status = '1';

  // Bahan baku dari invoice (wajib minimal satu).
  List<ProductionDetailInvoice> _availableInvoices = [];
  final Set<int> _selectedInvoiceIds = {};
  final Map<int, TextEditingController> _invoiceQtyControllers = {};
  bool _loadingInvoices = false;
  String? _invoicesError;

  bool _loadingStores = true;
  bool _loadingRecipes = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStores();
    _loadRecipes();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final ctrl in _invoiceQtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStores() async {
    try {
      final res = await PresenceService().getStores();
      if (!mounted) return;
      final parsed = res.where((s) => s.id > 0).toList();
      setState(() {
        _stores
          ..clear()
          ..addAll(parsed);
        _loadingStores = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat daftar toko: $e';
        _loadingStores = false;
      });
    }
  }

  Future<void> _loadRecipes() async {
    try {
      final res = await _recipeService.list();
      if (!mounted) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(res.items);
        _loadingRecipes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRecipes = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  /// Muat detail invoice yang belum terpakai di toko terpilih. Dipanggil
  /// setiap kali toko diganti; pilihan lama di-reset.
  Future<void> _loadAvailableInvoices(int storeId) async {
    setState(() {
      _loadingInvoices = true;
      _invoicesError = null;
      _selectedInvoiceIds.clear();
    });
    try {
      final items = await _prodService.availableDetailInvoices(storeId);
      if (!mounted) return;
      setState(() {
        _availableInvoices = items;
        _loadingInvoices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availableInvoices = [];
        _loadingInvoices = false;
        _invoicesError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onStoreChanged(int? v) {
    setState(() => _storeId = v);
    if (v != null) {
      _loadAvailableInvoices(v);
    } else {
      _availableInvoices = [];
      _selectedInvoiceIds.clear();
    }
  }

  void _toggleInvoiceItem(ProductionDetailInvoice di) {
    setState(() {
      if (_selectedInvoiceIds.contains(di.id)) {
        _selectedInvoiceIds.remove(di.id);
      } else {
        _selectedInvoiceIds.add(di.id);
        _invoiceQtyControllers.putIfAbsent(
          di.id,
          () => TextEditingController(
            text: _fmtQty(di.quantityProduct),
          ),
        );
      }
    });
  }

  List<ProductionItem> get _invoiceItems {
    return _selectedInvoiceIds.map((id) {
      final di = _availableInvoices.firstWhere((e) => e.id == id);
      final qty =
          double.tryParse(_invoiceQtyControllers[id]?.text ?? '') ??
              di.quantityProduct;
      return ProductionItem(
        product: ProductionProduct(
          id: di.productId ?? 0,
          name: di.productName,
        ),
        direction: ProductionItemDirection.input,
        source: ProductionItemSource.invoice,
        quantity: qty > 0 ? qty : di.quantityProduct,
        unit: di.unitId == null
            ? null
            : ProductionUnit(id: di.unitId!, name: di.unitName),
        detailInvoiceId: di.id,
      );
    }).toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_storeId == null) {
      setState(() => _error = 'Pilih toko terlebih dahulu');
      return;
    }
    if (_selectedInvoiceIds.isEmpty) {
      setState(() => _error =
          'Produksi wajib dibuat berdasarkan invoice: pilih minimal satu bahan baku dari invoice.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final created = await _prodService.create(
        storeId: _storeId!,
        date: _date,
        status: _status,
        recipeId: _selectedRecipe?.id,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        items: _invoiceItems,
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _submitting = false;
      });
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
      appBar: const GlassAppBar(title: Text('Buat Produksi')),
      body: _loadingStores
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppBarInsets.top(context),
                AppSpacing.md,
                AppSpacing.md + context.systemBottomInset + 80,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: AppSpacing.borderRadiusMD,
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapVerticalMD,
                    ],
                    FormSectionCard(
                      title: 'Lokasi & Waktu',
                      subtitle: 'Pilih toko unit kerja dan tanggal produksi',
                      icon: Icons.factory_outlined,
                      children: [
                        ModernDropdown<int>(
                          value: _storeId,
                          labelText: 'Toko / Unit',
                          hint: 'Pilih toko...',
                          isRequired: true,
                          prefixIcon: const Icon(Icons.storefront, size: 20),
                          items: _stores.map((s) => s.id).toList(),
                          getLabel: (v) {
                            final s = _stores.firstWhere((e) => e.id == v,
                                orElse: () => StoreModel(
                                    id: 0,
                                    nickname: '',
                                    latitude: 0,
                                    longitude: 0));
                            return s.nickname;
                          },
                          onChanged: _onStoreChanged,
                          validator: (v) => v == null ? 'Pilih toko' : null,
                        ),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: AppSpacing.borderRadiusMD,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Tanggal Produksi',
                              prefixIcon:
                                  const Icon(Icons.calendar_today, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: AppSpacing.borderRadiusMD,
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            child: Text(
                              '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                    FormSectionCard(
                      title: 'Bahan Baku dari Invoice (Wajib)',
                      subtitle:
                          'Produksi wajib dibuat berdasarkan invoice pembelian '
                          '— pilih bahan yang belum dipakai produksi lain',
                      icon: Icons.receipt_long_rounded,
                      children: [
                        if (_storeId == null)
                          _invoiceHint(
                            'Pilih toko terlebih dahulu untuk melihat bahan '
                            'baku dari invoice.',
                            Icons.info_outline,
                          )
                        else if (_loadingInvoices)
                          const Padding(
                            padding: AppSpacing.paddingMD,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          )
                        else if (_invoicesError != null)
                          _invoiceHint(_invoicesError!, Icons.error_outline)
                        else if (_availableInvoices.isEmpty)
                          _invoiceHint(
                            'Tidak ada bahan baku dari invoice yang belum '
                            'terpakai di toko ini. Buat invoice pembelian '
                            'terlebih dahulu.',
                            Icons.folder_off_outlined,
                          )
                        else
                          ..._availableInvoices.map(_buildInvoiceTile),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                    FormSectionCard(
                      title: 'Formula & Resep',
                      subtitle:
                          'Gunakan resep untuk auto-prefill bahan baku otomatis',
                      icon: Icons.menu_book_rounded,
                      children: [
                        if (_loadingRecipes)
                          const Padding(
                            padding: AppSpacing.paddingMD,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else ...[
                          ModernDropdown<Recipe?>(
                            value: _selectedRecipe,
                            labelText: 'Resep Produksi (opsional)',
                            hint: 'Pilih resep...',
                            prefixIcon: const Icon(Icons.restaurant_menu, size: 20),
                            items: [null, ..._recipes],
                            getLabel: (r) {
                              if (r == null) return '— Tanpa resep (input manual) —';
                              return '${r.product.name} (Hasil: ${_fmtQty(r.outputQty)}${r.outputUnit != null ? ' ${r.outputUnit!.name}' : ''})';
                            },
                            onChanged: (v) => setState(() => _selectedRecipe = v),
                          ),
                          if (_selectedRecipe != null) ...[
                            _recipePreview(_selectedRecipe!),
                          ],
                        ],
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                    FormSectionCard(
                      title: 'Catatan Produksi',
                      icon: Icons.edit_note_rounded,
                      children: [
                        TextFormField(
                          controller: _notesCtrl,
                          decoration: InputDecoration(
                            labelText: 'Catatan (opsional)',
                            hintText: 'Keterangan batch produksi...',
                            border: OutlineInputBorder(
                              borderRadius: AppSpacing.borderRadiusMD,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeBottomBar(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ModernButton(
            text: _submitting ? 'Menyimpan...' : 'Simpan & Lanjut ke Detail',
            onPressed: _submitting ? null : _submit,
            isLoading: _submitting,
            icon: Icons.save_rounded,
          ),
        ),
      ),
    );
  }

  Widget _invoiceHint(String message, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tile pilihan bahan baku dari detail invoice. Saat terpilih, muncul
  /// field qty (default = qty pembelian di invoice) yang bisa disesuaikan.
  Widget _buildInvoiceTile(ProductionDetailInvoice di) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final checked = _selectedInvoiceIds.contains(di.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: checked
            ? colorScheme.primary.withValues(alpha: 0.06)
            : colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: checked
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: checked ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleInvoiceItem(di),
            borderRadius: AppSpacing.borderRadiusMD,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: checked,
                    onChanged: (_) => _toggleInvoiceItem(di),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          di.productName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (di.invoicePurchaseId != null)
                              'INV #${di.invoicePurchaseId}',
                            if (di.invoiceDate?.isNotEmpty == true)
                              di.invoiceDate!,
                            'Beli: ${_fmtQty(di.quantityProduct)}'
                                '${di.unitName.isNotEmpty ? ' ${di.unitName}' : ''}',
                          ].join(' • '),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (checked)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Qty dipakai',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      controller: _invoiceQtyControllers[di.id],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        suffixText:
                            di.unitName.isNotEmpty ? di.unitName : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.borderRadiusSM,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _recipePreview(Recipe r) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Bahan baku dari resep (otomatis diisi):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          ...r.ingredients.map((ing) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        '${ing.product.name}${ing.isOptional ? ' (opsional)' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${_fmtQty(ing.quantity)}${ing.unit != null ? ' ${ing.unit!.name}' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _fmtQty(double q) =>
      q.truncateToDouble() == q ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}
