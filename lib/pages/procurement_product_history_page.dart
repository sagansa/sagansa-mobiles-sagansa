import 'package:fl_chart/fl_chart.dart';
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
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

/// Detail riwayat pembelian satu bahan baku (admin): ringkasan statistik,
/// tren harga satuan (chart), dan daftar riwayat invoice.
/// Filter: toko (sheet) + tahun (chip).
class ProcurementProductHistoryPage extends StatefulWidget {
  final int productId;
  final String productName;
  final int? storeId;
  final String storeLabel;

  const ProcurementProductHistoryPage({
    super.key,
    required this.productId,
    required this.productName,
    this.storeId,
    required this.storeLabel,
  });

  @override
  State<ProcurementProductHistoryPage> createState() =>
      _ProcurementProductHistoryPageState();
}

/// Satu titik chart — per pembelian, atau rata-rata bulanan saat titik
/// terlalu banyak agar grafik tetap terbaca.
class _ChartPoint {
  final DateTime? date;
  final double value;
  final String tooltipDetail;

  const _ChartPoint({
    required this.date,
    required this.value,
    required this.tooltipDetail,
  });
}

class _ProcurementProductHistoryPageState
    extends State<ProcurementProductHistoryPage> {
  final ProcurementService _service = ProcurementService();
  final StoreService _storeService = StoreService();

  ProductPurchaseDetail? _detail;
  String? _errorMessage;

  // Filter lokal halaman ini (nilai awal diwarisi dari halaman list).
  List<StoreModel> _stores = [];
  int? _storeId;
  int? _year;

  static const int _maxChartPoints = 30;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
    _loadStores();
    _load();
  }

  Future<void> _loadStores() async {
    try {
      final stores = await _storeService.getStores();
      if (mounted) setState(() => _stores = stores);
    } catch (_) {
      // Filter toko opsional — data tetap tampil tanpa daftar toko.
    }
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final detail = await _service.getProductPurchaseDetail(
        widget.productId,
        storeId: _storeId,
        year: _year,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Gagal memuat riwayat pembelian ${widget.productName}.');
    }
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Toko',
      fields: [
        // Opsi "Semua Toko" (null) otomatis ditambahkan oleh picker.
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
          _load();
        }
      },
      onReset: () {
        if (_storeId != null) {
          _storeId = null;
          _load();
        }
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

  String get _unitName => _detail?.unitName ?? '';

  /// Titik chart dari riwayat (API terbaru-dulu → dibalik jadi kronologis).
  /// > [_maxChartPoints] titik → agregasi rata-rata tertimbang qty per bulan.
  List<_ChartPoint> _buildChartPoints(List<ProductPurchaseHistoryItem> history) {
    final chronological = history.reversed.toList();

    if (chronological.length <= _maxChartPoints) {
      return [
        for (final item in chronological)
          _ChartPoint(
            date: item.date,
            value: item.unitPrice.toDouble(),
            tooltipDetail: [
              DateFormat('d MMM yyyy', 'id_ID')
                  .format(item.date ?? DateTime.now()),
              if (item.supplierName != null) item.supplierName!,
              '${_formatQty(item.quantity)} $_unitName',
              'Total Rp ${FormatUtils.formatNumber(item.subtotal)}',
            ].join('\n'),
          ),
      ];
    }

    // Agregasi bulanan: rata-rata tertimbang qty (total nilai / total qty).
    final byMonth = <String, List<ProductPurchaseHistoryItem>>{};
    for (final item in chronological) {
      final d = item.date;
      final key = d == null ? 'x' : '${d.year}-${d.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(item);
    }

    final entries = byMonth.entries.toList()
      ..sort((a, b) {
        final da = a.value.first.date;
        final db = b.value.first.date;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

    return [
      for (final entry in entries)
        () {
          final items = entry.value;
          final totalValue =
              items.fold<double>(0, (sum, i) => sum + i.subtotal);
          final totalQty =
              items.fold<double>(0, (sum, i) => sum + i.quantity);
          final monthLabel = items.first.date == null
              ? '—'
              : DateFormat('MMM yyyy', 'id_ID').format(items.first.date!);
          return _ChartPoint(
            date: items.first.date,
            value: totalQty > 0 ? totalValue / totalQty : 0,
            tooltipDetail:
                '$monthLabel • ${items.length} pembelian\n(total nilai ${totalValue.round()} / total qty ${_formatQty(totalQty)})',
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = _detail;

    return AppPageScaffold(
      titleText: widget.productName,
      actions: [
        BarButtonCluster(actions: [
          BarButtonSpec(
            icon: Icons.tune,
            tooltip: 'Filter Toko',
            badgeCount: _storeId != null ? 1 : 0,
            onTap: _openFilterSheet,
          ),
        ]),
      ],
      isLoading: _detail == null && _errorMessage == null,
      errorMessage: _errorMessage,
      onRetry: _load,
      bodyPadding: EdgeInsets.zero,
      body: detail == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                            [
                              'Riwayat beli: $_storeLabel',
                              if (_year != null) '$_year',
                            ].join(' • '),
                            style: textTheme.labelMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (detail.availableYears.isNotEmpty) ...[
                  AppSpacing.gapVerticalXS,
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      children: [
                        ChoiceChip(
                          label: const Text('Semua Tahun'),
                          selected: _year == null,
                          onSelected: (_) {
                            if (_year != null) {
                              setState(() => _year = null);
                              _load();
                            }
                          },
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        for (var i = 0; i < detail.availableYears.length; i++) ...[
                          ChoiceChip(
                            label: Text('${detail.availableYears[i]}'),
                            selected: _year == detail.availableYears[i],
                            onSelected: (_) {
                              if (_year != detail.availableYears[i]) {
                                setState(
                                    () => _year = detail.availableYears[i]);
                                _load();
                              }
                            },
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: detail.history.isEmpty
                      ? EmptyState(
                          icon: Icons.history_rounded,
                          title: _year == null
                              ? 'Belum ada riwayat pembelian untuk ${_storeLabel.toLowerCase()}.'
                              : 'Tidak ada pembelian pada $_year untuk ${_storeLabel.toLowerCase()}.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            children: [
                              _buildSummaryCard(detail, textTheme),
                              AppSpacing.gapVerticalMD,
                              _buildTrendCard(detail),
                              AppSpacing.gapVerticalMD,
                              _buildHistoryHeader(detail, textTheme),
                              AppSpacing.gapVerticalSM,
                              ...detail.history.map(
                                (item) => _buildHistoryRow(item, textTheme),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(ProductPurchaseDetail detail, TextTheme textTheme) {
    final s = detail.summary;

    Widget row(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: textTheme.bodySmall?.copyWith(color: valueColor),
              ),
            ),
          ],
        ),
      );
    }

    // Harga terakhir vs rata-rata — analisa arah harga.
    final lastPrice =
        detail.history.isNotEmpty ? detail.history.first.unitPrice : 0;
    String? lastVsAvg;
    Color? lastVsAvgColor;
    if (s.avgUnitPrice > 0 && lastPrice > 0 && detail.history.length > 1) {
      final delta = ((lastPrice - s.avgUnitPrice) / s.avgUnitPrice) * 100;
      final sign = delta >= 0 ? '+' : '';
      lastVsAvg =
          'Rp ${FormatUtils.formatNumber(lastPrice)} ($sign${delta.toStringAsFixed(0)}%)';
      lastVsAvgColor = delta > 0 ? AppColors.error : AppColors.success;
    }

    return SectionCard(
      margin: EdgeInsets.zero,
      title: 'Ringkasan Pembelian',
      icon: Icons.analytics_outlined,
      iconColor: AppColors.info,
      child: Column(
        children: [
          if (s.totalInvoices > 0) ...[
            row('Total belanja',
                'Rp ${FormatUtils.formatNumber(s.totalValue)} • ${s.totalInvoices} invoice'),
            row('Total qty dibeli', '${_formatQty(s.totalQuantity)} $_unitName'),
            if (lastVsAvg != null)
              row('Terakhir vs rata-rata', lastVsAvg, valueColor: lastVsAvgColor),
            row('Harga rata-rata',
                'Rp ${FormatUtils.formatNumber(s.avgUnitPrice)}/$_unitName'),
            row('Rentang harga',
                'Rp ${FormatUtils.formatNumber(s.minUnitPrice)} – Rp ${FormatUtils.formatNumber(s.maxUnitPrice)}'),
            row(
              'Periode',
              [
                if (s.firstDate != null) FormatUtils.formatDate(s.firstDate!),
                if (s.lastDate != null) FormatUtils.formatDate(s.lastDate!),
              ].join(' – '),
            ),
          ] else
            Text(
              'Belum ada data pembelian pada rentang ini.',
              style: textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(ProductPurchaseDetail detail) {
    final points = _buildChartPoints(detail.history);
    final isMonthly = detail.history.length > _maxChartPoints;

    return SectionCard(
      margin: EdgeInsets.zero,
      title: 'Tren Harga Satuan',
      icon: Icons.show_chart_rounded,
      iconColor: AppColors.info,
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: AppSpacing.borderRadiusSM,
          ),
          child: Text(
            isMonthly ? 'Rata-rata bulanan' : 'Per pembelian',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
      child: points.length < 2
          ? Text(
              'Butuh minimal 2 pembelian untuk menampilkan grafik tren.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _buildPriceChart(points, showDots: !isMonthly),
            ),
    );
  }

  Widget _buildPriceChart(List<_ChartPoint> points, {required bool showDots}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final values = points.map((p) => p.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) * 0.25 + 1;
    final yInterval = (((maxY - minY) / 3).clamp(1.0, double.infinity))
        .toDouble();
    final labelIndexes = <int>{
      0,
      points.length ~/ 2,
      points.length - 1,
    };

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minX: -0.35,
          maxX: points.length <= 1 ? 0.35 : points.length - 0.65,
          minY: (minY - yPad).clamp(0, double.infinity),
          maxY: maxY + yPad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: yInterval,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    FormatUtils.formatRupiahCompact(value.round()),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if ((value - index).abs() > 0.001 ||
                      index < 0 ||
                      index >= points.length ||
                      !labelIndexes.contains(index)) {
                    return const SizedBox.shrink();
                  }
                  final date = points[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      date == null ? '—' : DateFormat('d/M/yy').format(date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Tap/tahan titik → tooltip detail pembelian titik itu.
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.primary,
              tooltipBorderRadius: BorderRadius.circular(8),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) =>
                  touchedSpots.map((spot) {
                final index = spot.spotIndex;
                if (index < 0 || index >= points.length) return null;
                final point = points[index];
                return LineTooltipItem(
                  'Rp ${FormatUtils.formatNumber(point.value.round())}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  children: [
                    TextSpan(
                      text: '\n${point.tooltipDetail}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.normal,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: points.length > 2,
              curveSmoothness: 0.18,
              preventCurveOverShooting: true,
              color: cs.primary,
              barWidth: 2.2,
              // Titik disembunyikan saat seri bulanan (terlalu rapat) —
              // garis + tooltip tetap terbaca.
              dotData: FlDotData(
                show: showDots,
                getDotPainter: (spot, percent, barData, index) {
                  final isLatest = index == points.length - 1;
                  return FlDotCirclePainter(
                    radius: isLatest ? 4.4 : 3.2,
                    color: isLatest ? AppColors.success : cs.primary,
                    strokeWidth: isLatest ? 2 : 1.5,
                    strokeColor: cs.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withValues(alpha: 0.14),
                    cs.primary.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(ProductPurchaseDetail detail, TextTheme textTheme) {
    return Row(
      children: [
        Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.info),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Riwayat Pembelian (${detail.history.length})',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(ProductPurchaseHistoryItem item, TextTheme textTheme) {
    final statusType = switch (item.paymentStatus) {
      '2' => StatusType.success,
      '3' => StatusType.error,
      _ => StatusType.warning,
    };

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.date == null
                        ? '—'
                        : DateFormat('d MMM yyyy', 'id_ID').format(item.date!),
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(label: item.paymentLabel, type: statusType),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                '${_formatQty(item.quantity)} $_unitName',
                'Rp ${FormatUtils.formatNumber(item.unitPrice)}/$_unitName',
                if (item.supplierName != null) item.supplierName!,
                if (_storeId == null && item.storeName != null)
                  item.storeName!,
              ].join(' • '),
              style: textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Total: Rp ${FormatUtils.formatNumber(item.subtotal)}',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.info,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
