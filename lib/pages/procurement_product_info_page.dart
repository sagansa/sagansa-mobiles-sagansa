import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/procurement_model.dart';
import '../models/store_model.dart';
import '../services/procurement_service.dart';
import '../services/store_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/paginated_list_view.dart';
import '../widgets/status_badge.dart';
import 'procurement_product_history_page.dart';

/// Info beli bahan baku (admin): kapan terakhir dibeli per toko / semua
/// toko, harga satuan terakhir, dan qty yang sedang dalam invoice
/// belum lunas. Entry point: menu "Opsi lainnya" di ProcurementWorkflowPage.
class ProcurementProductInfoPage extends StatefulWidget {
  const ProcurementProductInfoPage({super.key});

  @override
  State<ProcurementProductInfoPage> createState() =>
      _ProcurementProductInfoPageState();
}

class _ProcurementProductInfoPageState
    extends State<ProcurementProductInfoPage> {
  final ProcurementService _service = ProcurementService();
  final StoreService _storeService = StoreService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<StoreModel> _stores = [];
  int? _storeId; // null = Semua Toko
  bool _isSearchVisible = false;
  String _query = '';

  final List<ProductPurchaseInfo> _items = [];
  bool _isLoading = true;
  bool _hasMore = false;
  int _page = 1;
  String? _errorMessage;

  /// Baris list = header seksi (bulan pembelian terakhir) + kartu produk.
  /// Header membuat urutan recency (date DESC dari backend) langsung
  /// terbaca — dalam tanggal yang sama urutan memang alfabetis.
  List<_InfoRow> _buildRows() {
    final rows = <_InfoRow>[];
    String? currentKey;
    for (final item in _items) {
      final last = item.lastPurchase;
      final hasLast = last != null && last.hasData;
      final date = hasLast ? last.date : null;
      final key = date == null ? 'none' : '${date.year}-${date.month}';
      if (key != currentKey) {
        currentKey = key;
        rows.add(_InfoRow.header(date == null
            ? 'Belum pernah dibeli'
            : DateFormat('MMMM yyyy', 'id_ID').format(date)));
      }
      rows.add(_InfoRow.product(item));
    }
    return rows;
  }

  @override
  void initState() {
    super.initState();
    _loadStores();
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    try {
      final stores = await _storeService.getStores();
      if (mounted) setState(() => _stores = stores);
    } catch (_) {
      // Filter toko opsional — daftar produk tetap tampil tanpa filter.
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _service.getProductPurchaseInfo(
        storeId: _storeId,
        query: _query,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result['data'] as List<ProductPurchaseInfo>);
        _hasMore = result['has_more'] as bool;
        _page = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat info pembelian bahan baku.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final result = await _service.getProductPurchaseInfo(
      storeId: _storeId,
      query: _query,
      page: _page + 1,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(result['data'] as List<ProductPurchaseInfo>);
      _hasMore = result['has_more'] as bool;
      _page += 1;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_query != value.trim()) {
        _query = value.trim();
        _reload();
      }
    });
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Toko',
      fields: [
        // Opsi "Semua Toko" (null) otomatis ditambahkan oleh picker —
        // tidak perlu (dan tidak boleh) diulang di sini.
        DropdownFilterField<int?>(
          label: 'Toko',
          value: _storeId,
          options: [for (final s in _stores) (s.id, s.nickname)],
        ),
      ],
      onApply: (values) {
        final storeId = values['Toko'] as int?;
        if (storeId != _storeId) {
          _storeId = storeId;
        }
        _reload();
      },
      onReset: () {
        _storeId = null;
        _reload();
      },
    );
  }

  String get _storeLabel {
    if (_storeId == null) return 'Semua Toko';
    final store = _stores.where((s) => s.id == _storeId).firstOrNull;
    return store?.nickname ?? 'Toko #$_storeId';
  }

  String _formatQty(double value) {
    final rounded = value.round();
    return value == rounded ? '$rounded' : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPageScaffold(
      titleText: 'Info Beli Bahan Baku',
      actions: [
        BarButtonCluster(actions: [
          if (!_isSearchVisible)
            BarButtonSpec(
              icon: Icons.search,
              tooltip: 'Cari bahan baku',
              onTap: () => setState(() => _isSearchVisible = true),
            ),
          if (_isSearchVisible)
            BarButtonSpec(
              icon: Icons.close_rounded,
              tooltip: 'Tutup pencarian',
              onTap: () {
                _searchController.clear();
                setState(() => _isSearchVisible = false);
                if (_query.isNotEmpty) {
                  _query = '';
                  _reload();
                }
              },
            ),
          BarButtonSpec(
            icon: Icons.tune,
            tooltip: 'Filter',
            badgeCount: _storeId != null ? 1 : 0,
            onTap: _openFilterSheet,
          ),
        ]),
      ],
      bottom: _isSearchVisible ? _buildSearchField(colorScheme) : null,
      bodyPadding: EdgeInsets.zero,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRetry: _reload,
      isEmpty: _items.isEmpty && !_isLoading && _errorMessage == null,
      emptyState: EmptyState(
        icon: Icons.inventory_2_outlined,
        title: _query.isEmpty
            ? 'Belum ada bahan baku.'
            : 'Tidak ada bahan baku yang cocok dengan "$_query".',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Konten melewati di balik app bar kaca — beri jarak atas sesuai
          // posisi app bar (pola list page lain).
          Padding(
            padding: EdgeInsets.only(top: AppBarInsets.top(context)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Riwayat beli: $_storeLabel',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: Builder(builder: (context) {
                final rows = _buildRows();
                return PaginatedListView<_InfoRow>(
                  items: rows,
                  hasMore: _hasMore,
                  onLoadMore: _loadMore,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return row.isHeader
                        ? _buildSectionHeader(row.headerLabel!, textTheme)
                        : _buildProductCard(
                            row.product!, colorScheme, textTheme);
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSearchField(ColorScheme colorScheme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm + AppSpacing.xs,
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari nama bahan baku...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    tooltip: 'Bersihkan pencarian',
                    onPressed: () {
                      _searchController.clear();
                      if (_query.isNotEmpty) {
                        _query = '';
                        _reload();
                      }
                    },
                  )
                : null,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  Widget _buildProductCard(
    ProductPurchaseInfo product,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final last = product.lastPurchase;
    final hasLast = last != null && last.hasData;
    final inProcess = product.inProcess;
    final hasInProcess = inProcess != null && inProcess.hasData;
    final recent = product.recentPurchases
        .where((p) => p.hasData)
        .take(5)
        .toList(growable: false);

    return InkWell(
      borderRadius: AppSpacing.borderRadiusLG,
      onTap: () => _openDetail(product),
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppSpacing.borderRadiusLG,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: AppSpacing.borderRadiusSM,
                      color: colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      product.name,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.unitName.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(
                      label: product.unitName,
                      type: StatusType.neutral,
                    ),
                  ],
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.info),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (recent.isNotEmpty)
                _buildRecentPurchasesBox(product, recent, textTheme, colorScheme)
              else if (hasLast)
                // Fallback bila backend belum mengirim recent_purchases.
                Text(
                  [
                    'Rp ${FormatUtils.formatNumber(last.unitPrice)}/${product.unitName}',
                    if (last.quantity > 0)
                      '${_formatQty(last.quantity)} ${product.unitName}',
                    if (last.date != null)
                      'Terakhir beli ${FormatUtils.formatDate(last.date!)}',
                    if (last.supplierName != null) last.supplierName!,
                    if (_storeId == null && last.storeName != null)
                      last.storeName!,
                  ].join(' • '),
                  style: textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  'Belum pernah dibeli',
                  style: textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (hasInProcess) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: AppSpacing.borderRadiusSM,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            '${inProcess.invoiceCount} invoice belum lunas',
                            '${_formatQty(inProcess.quantity)} ${product.unitName}',
                            if (inProcess.oldestInvoiceDate != null)
                              'terlama ${FormatUtils.formatDate(inProcess.oldestInvoiceDate!)}',
                          ].join(' • '),
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(ProductPurchaseInfo product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcurementProductHistoryPage(
          productId: product.id,
          productName: product.name,
          storeId: _storeId,
          storeLabel: _storeLabel,
        ),
      ),
    );
  }

  /// Box hingga 5 pembelian terakhir (pola "Harga beli sebelumnya" di
  /// invoice detail). Baris pertama (terbaru) ditonjolkan.
  Widget _buildRecentPurchasesBox(
    ProductPurchaseInfo product,
    List<ProductLastPurchase> recent,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: AppColors.info),
              const SizedBox(width: 6),
              Text(
                'Pembelian Terakhir (${recent.length})',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < recent.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                [
                  'Rp ${FormatUtils.formatNumber(recent[i].unitPrice)}'
                  '/${product.unitName}',
                  if (recent[i].quantity > 0)
                    '${_formatQty(recent[i].quantity)} ${product.unitName}',
                  if (recent[i].date != null)
                    FormatUtils.formatDate(recent[i].date!),
                  if (recent[i].supplierName != null) recent[i].supplierName!,
                  // Nama store hanya relevan di mode Semua Toko.
                  if (_storeId == null && recent[i].storeName != null)
                    recent[i].storeName!,
                ].join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color:
                      i == 0 ? AppColors.info : colorScheme.onSurfaceVariant,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.info),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris list Info Beli Bahan Baku: header seksi bulan atau kartu produk.
class _InfoRow {
  final String? headerLabel;
  final ProductPurchaseInfo? product;

  const _InfoRow._(this.headerLabel, this.product);

  factory _InfoRow.header(String label) => _InfoRow._(label, null);

  factory _InfoRow.product(ProductPurchaseInfo product) =>
      _InfoRow._(null, product);

  bool get isHeader => headerLabel != null;
}
