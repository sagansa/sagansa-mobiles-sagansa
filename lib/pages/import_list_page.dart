import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/enums/import_stage.dart';
import '../models/import_model.dart';
import '../services/import_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/modern_button.dart';
import '../widgets/paginated_list_view.dart';
import '../widgets/status_badge.dart';
import 'import_detail_page.dart';
import 'import_form_page.dart';
import 'import_price_trend_page.dart';
import 'import_selling_price_page.dart';

/// Daftar proses impor barang + filter tahap.
///
/// Entry dari menu Transaksi (admin/super_admin); baca dibuka untuk semua
/// user login.
class ImportListPage extends StatefulWidget {
  const ImportListPage({super.key});

  @override
  State<ImportListPage> createState() => _ImportListPageState();
}

class _ImportListPageState extends State<ImportListPage> {
  final ImportService _service = ImportService();

  List<ImportPurchase> _imports = [];
  Map<String, int> _stageCounts = {};
  String? _selectedStage;
  bool _isLoading = true;
  String? _error;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = await _service.getImports(
        page: 1,
        stage: _selectedStage,
      );
      if (!mounted) return;
      setState(() {
        _imports = result['data'] as List<ImportPurchase>;
        _stageCounts =
            Map<String, int>.from(result['stage_counts'] as Map<String, int>);
        _hasMore = result['has_more'] == true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final result = await _service.getImports(
      page: _page + 1,
      stage: _selectedStage,
    );
    if (!mounted) return;
    setState(() {
      _page++;
      _imports.addAll(result['data'] as List<ImportPurchase>);
      _hasMore = result['has_more'] == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Impor Barang',
      // Tombol buat proses baru = kapsul app bar (standar list page lain,
      // mis. Bensin & Servis) — bukan floating button.
      actions: [
        BarButtonCluster(actions: [
          BarButtonSpec(
            icon: Icons.sell_outlined,
            iconSize: 22,
            tooltip: 'Harga jual (info)',
            onTap: _openSellingPrices,
          ),
          BarButtonSpec(
            icon: Icons.show_chart_rounded,
            iconSize: 22,
            tooltip: 'Trend harga satuan',
            onTap: _openPriceTrends,
          ),
          BarButtonSpec(
            icon: Icons.add_rounded,
            iconSize: 22,
            tooltip: 'Impor baru',
            onTap: _openForm,
          ),
        ]),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: _buildStageStrip(),
      ),
      // Padding atas ditangani scrollable (clearance appbar + strip tahap);
      // tetap jaga inset horizontal standar layar.
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: _imports.isEmpty && !_isLoading && _error == null,
      emptyState: EmptyState(
        icon: Icons.public_outlined,
        title: _selectedStage == null
            ? 'Belum ada proses impor'
            : 'Tidak ada proses di tahap ini',
        subtitle: _selectedStage == null
            ? 'Buat draft proses impor untuk mulai mencatat pembelian barang '
                'dari supplier luar negeri beserta biaya-biayanya.'
            : 'Coba pilih tahap lain atau buat proses impor baru.',
        action: ModernButton(
          text: 'Buat Proses Impor',
          icon: Icons.add_rounded,
          fullWidth: false,
          height: 40,
          onPressed: () => _openForm(),
        ),
      ),
      body: Builder(
        // Konteks DI DALAM body Scaffold: AppBarInsets membaca tinggi app
        // bar penuh (toolbar + strip tahap) dari MediaQuery, bukan estimasi
        // — kartu pertama tidak lagi tertutup strip.
        builder: (bodyContext) => RefreshIndicator(
          onRefresh: _load,
          child: PaginatedListView<ImportPurchase>(
            items: _imports,
            hasMore: _hasMore,
            onLoadMore: _loadMore,
            padding: EdgeInsets.only(
              top: AppBarInsets.top(bodyContext) + AppSpacing.md,
              bottom: AppSpacing.xl,
            ),
            itemBuilder: (context, i) => _ImportCard(
              importPurchase: _imports[i],
              onTap: () => _openDetail(_imports[i].id),
            ),
          ),
        ),
      ),
    );
  }

  /// Strip filter tahap di bawah appbar — pill scrollable dengan jumlah
  /// per tahap (pola filter row fuel service).
  Widget _buildStageStrip() {
    final cs = Theme.of(context).colorScheme;
    final stages = [...ImportStage.flow];

    return Container(
      height: 44,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _stagePill(
            cs: cs,
            label: 'Semua',
            count: _stageCounts.values.fold<int>(0, (a, b) => a + b),
            selected: _selectedStage == null,
            onTap: () {
              setState(() => _selectedStage = null);
              _load();
            },
          ),
          for (final stage in stages) ...[
            AppSpacing.gapHorizontalSM,
            _stagePill(
              cs: cs,
              label: stage.displayLabel,
              count: _stageCounts[stage.name] ?? 0,
              selected: _selectedStage == stage.name,
              onTap: () {
                setState(() => _selectedStage =
                    _selectedStage == stage.name ? null : stage.name);
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _stagePill({
    required ColorScheme cs,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? cs.onPrimary.withValues(alpha: 0.8)
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm() async {
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(builder: (_) => const ImportFormPage()),
    );
    if (!mounted || result == null) return;

    await _load();
    if (!mounted) return;
    if (result is int) {
      // Kembali ke list dulu — jangan paksa pengguna masuk ke input
      // realisasi. Detail tetap satu ketuk lewat aksi snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Proses impor berhasil dibuat.'),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () {
              if (mounted) _openDetail(result);
            },
          ),
        ),
      );
    }
  }

  Future<void> _openPriceTrends() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ImportPriceTrendPage()),
    );
  }

  Future<void> _openSellingPrices() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ImportSellingPricePage()),
    );
  }

  Future<void> _openDetail(int id) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportDetailPage(importId: id),
      ),
    );
    if (mounted) _load();
  }
}

/// Kartu satu proses impor: header supplier bertint tahap, progres tahap
/// (titik 7 alur), dan ringkasan estimasi vs realisasi.
class _ImportCard extends StatelessWidget {
  final ImportPurchase importPurchase;
  final VoidCallback onTap;

  const _ImportCard({
    required this.importPurchase,
    required this.onTap,
  });

  String _dateLabel(ImportPurchase import) {
    final date = import.purchaseDate;
    return date == null
        ? 'Tanggal —'
        : DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  Color _stageColor(BuildContext context, ImportStage stage) {
    final cs = Theme.of(context).colorScheme;
    return switch (stage.badgeType) {
      StatusType.success => AppColors.success,
      StatusType.warning => AppColors.warning,
      StatusType.error => cs.error,
      StatusType.info => AppColors.info,
      StatusType.neutral => AppColors.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final import = importPurchase;
    final stageColor = _stageColor(context, import.stage);
    final stageIdx = import.stage.flowIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: import.stage.isTerminal
              ? stageColor.withValues(alpha: 0.4)
              : cs.outline.withValues(alpha: 0.15),
          width: import.stage.isTerminal ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: supplier + tahap, tint mengikuti warna tahap.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: stageColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusMD),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.public_outlined,
                      size: 17,
                      color: stageColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          import.supplierName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(import.invoiceNumber?.isNotEmpty ?? false) ? import.invoiceNumber : 'Tanpa no. invoice'}'
                          ' • ${_dateLabel(import)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${import.items.length} produk • '
                          'kurs Rp ${FormatUtils.formatAmount(import.exchangeRate, decimals: 2)} / ${import.currency}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: import.stage.displayLabel,
                    type: import.stage.badgeType,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm + 2,
                AppSpacing.md,
                AppSpacing.sm + 2,
              ),
              child: _buildStageProgress(theme, cs, stageIdx),
            ),
            const Divider(
                height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm + 2,
                AppSpacing.md,
                AppSpacing.sm + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Satu angka: realisasi bila tersedia, estimasi sebagai
                  // fallback selama belum — tanpa perbandingan/selisih.
                  _totalColumn(
                    theme,
                    cs,
                    label: import.totalReal > 0 ? 'Realisasi' : 'Estimasi',
                    value: FormatUtils.formatRupiah(
                      import.totalReal > 0
                          ? import.totalReal
                          : import.totalEstimate,
                    ),
                    color: cs.onSurface,
                  ),
                ],
              ),
            ),
            if (import.items.isNotEmpty) ...[
              const Divider(
                  height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sell_outlined,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Harga satuan produk',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ...import.items.map(
                      (item) => _buildItemPriceRow(theme, cs, item),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Baris harga satuan per produk pada kartu list: realisasi bila
  /// tersedia, fallback estimasi selama belum — chip kecil menandai
  /// sumbernya. Info kecil memuat qty & harga valuta asli agar konteks
  /// impor tetap terlihat.
  Widget _buildItemPriceRow(
    ThemeData theme,
    ColorScheme cs,
    ImportItem item,
  ) {
    final realized = item.priceIsRealized;
    final price = item.displayUnitPriceIdr;
    final accent = realized ? AppColors.success : cs.onSurfaceVariant;
    final unit = item.unitName;
    final qty = FormatUtils.formatAmount(item.quantity, decimals: 3);
    final foreign =
        FormatUtils.formatAmount(item.unitPriceForeign, decimals: 4);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$qty${unit.isEmpty ? '' : ' $unit'} • '
                  '$foreign ${importPurchase.currency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price == null
                    ? '—'
                    : '${FormatUtils.formatRupiah(price)}'
                        '${unit.isEmpty ? '' : ' / $unit'}',
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: price == null ? cs.onSurfaceVariant : accent,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: Text(
                  realized ? 'Realisasi' : 'Estimasi',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kolom nominal kartu: label kecil + nilai yang menyusut (bukan
  /// terpotong "Rp 1.234.567…") saat mencapai ratusan juta / miliar.
  Widget _totalColumn(
    ThemeData theme,
    ColorScheme cs, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            value,
            maxLines: 1,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Progres alur 7 tahap sebagai deret titik + konektor; tahap aktif
  /// diberi ring. Proses batal/final menampilkan titik penuh di tahapnya.
  Widget _buildStageProgress(ThemeData theme, ColorScheme cs, int stageIdx) {
    if (importPurchase.stage.isCancelled) {
      return Row(
        children: [
          Icon(Icons.block_outlined, size: 14, color: cs.error),
          const SizedBox(width: 6),
          Text(
            'Dibatalkan — data & dokumen tersimpan sebagai arsip',
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Tahap ${stageIdx >= 0 ? stageIdx + 1 : '-'}/7',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: SizedBox(
            height: 13,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dotSize = 9.0;
                const gap = 5.0;
                final maxConnectors =
                    (constraints.maxWidth / (dotSize + gap)).floor() - 1;
                final connectorCount = maxConnectors.clamp(0, 6);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < ImportStage.flow.length; i++) ...[
                      if (i > 0 && i <= connectorCount)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: stageIdx >= 0 && i <= stageIdx
                                ? AppColors.success
                                : cs.outlineVariant.withValues(alpha: 0.6),
                          ),
                        )
                      else if (i > 0)
                        const SizedBox(width: gap),
                      Container(
                        width: i == stageIdx ? dotSize + 4 : dotSize,
                        height: i == stageIdx ? dotSize + 4 : dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stageIdx >= 0 && i < stageIdx
                              ? AppColors.success
                              : i == stageIdx
                                  ? _stageColor(context, ImportStage.flow[i])
                                  : Colors.transparent,
                          border: i == stageIdx
                              ? Border.all(
                                  color:
                                      _stageColor(context, ImportStage.flow[i]),
                                  width: 2,
                                )
                              : (stageIdx >= 0 && i < stageIdx)
                                  ? null
                                  : Border.all(
                                      color: cs.outlineVariant
                                          .withValues(alpha: 0.8),
                                      width: 1.5,
                                    ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
