import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sales_dashboard_model.dart';
import '../services/sales_dashboard_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/format_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/ios_segmented_control.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/modern_picker_sheet.dart';
import '../widgets/search_text_field.dart';
import '../widgets/skeleton_loading.dart';

class SalesDashboardPage extends StatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  State<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends State<SalesDashboardPage> {
  SalesPeriode _periode = SalesPeriode.year;
  int? _selectedYear;
  int _tabIndex = 0;
  bool _accessChecked = false;
  bool _canAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    bool ok = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString) as Map<String, dynamic>;
        final roles = List<String>.from(userData['roles'] ?? []);
        ok = roles.contains('admin') || roles.contains('super_admin');
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _canAccess = ok;
      _accessChecked = true;
    });
  }

  void _onYearSelected(int? year) {
    if (year == null) return;
    final currentYear = DateTime.now().year;
    setState(() {
      _selectedYear = year;
      if (year == currentYear) {
        _periode = SalesPeriode.year;
      } else if (year == currentYear - 1) {
        _periode = SalesPeriode.lastYear;
      } else {
        _periode = SalesPeriode.year;
      }
    });
  }

  Future<void> _showYearPickerSheet() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(7, (i) => currentYear - i); // e.g. 2026 .. 2020

    ModernPickerSheet.showFromTuples<int>(
      context: context,
      title: 'Pilih Tahun Penjualan',
      options: years.map((y) {
        String label = 'Tahun $y';
        if (y == currentYear) label += ' (Tahun Ini)';
        if (y == currentYear - 1) label += ' (Tahun Lalu)';
        return (y, label);
      }).toList(),
      selectedItem: _selectedYear ?? currentYear,
      onSelected: (v) {
        if (v != null) {
          _onYearSelected(v);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessChecked) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: GlassAppBar(title: const Text('Dashboard Penjualan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_canAccess) {
      return Scaffold(
        appBar: GlassAppBar(title: const Text('Dashboard Penjualan')),
        body: const Center(
          child: Padding(
            padding: AppSpacing.paddingLG,
            child: Text('Anda tidak punya akses ke fitur ini.'),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Dashboard Penjualan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: IosSegmentedControl<int>(
            segments: const {
              0: 'Ringkasan',
              1: 'Kategori',
              2: 'Produk',
              3: 'Channel',
            },
            groupValue: _tabIndex,
            onValueChanged: (index) {
              setState(() => _tabIndex = index);
            },
          ),
        ),
      ),
      body: Column(
        children: [
          _buildPeriodeRow(),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _SummaryTab(
                  key: ValueKey('summary-${_periode.apiValue}-$_selectedYear'),
                  periode: _periode,
                  year: _selectedYear,
                  onYearChanged: _onYearSelected,
                ),
                _CategoriesTab(
                  key: ValueKey('categories-${_periode.apiValue}-$_selectedYear'),
                  periode: _periode,
                  year: _selectedYear,
                  onYearChanged: _onYearSelected,
                ),
                _ProductsTab(
                  key: ValueKey('products-${_periode.apiValue}-$_selectedYear'),
                  periode: _periode,
                  year: _selectedYear,
                  onYearChanged: _onYearSelected,
                ),
                _ChannelsTab(
                  key: ValueKey('channels-${_periode.apiValue}-$_selectedYear'),
                  periode: _periode,
                  year: _selectedYear,
                  onYearChanged: _onYearSelected,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index != 3) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildPeriodeRow() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentYear = DateTime.now().year;
    final isCustomHistoricalYear = _selectedYear != null &&
        _selectedYear != currentYear &&
        _selectedYear != currentYear - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...SalesPeriode.values.map((p) {
              final isSelected = !isCustomHistoricalYear && p == _periode;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _periode = p;
                      if (p == SalesPeriode.year) {
                        _selectedYear = currentYear;
                      } else if (p == SalesPeriode.lastYear) {
                        _selectedYear = currentYear - 1;
                      } else {
                        _selectedYear = null;
                      }
                    });
                  },
                  borderRadius: AppSpacing.borderRadiusSM,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.secondary.withValues(alpha: 0.22) : cs.primaryContainer)
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : cs.surfaceContainerHighest.withValues(alpha: 0.45)),
                      borderRadius: AppSpacing.borderRadiusSM,
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? AppColors.gold : cs.primary)
                            : cs.outlineVariant.withValues(alpha: 0.3),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? AppColors.gold : cs.onPrimaryContainer)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Historical Year Picker Chip
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _showYearPickerSheet,
                borderRadius: AppSpacing.borderRadiusSM,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCustomHistoricalYear
                        ? (isDark ? AppColors.secondary.withValues(alpha: 0.22) : cs.primaryContainer)
                        : (isDark ? Colors.white.withValues(alpha: 0.05) : cs.surfaceContainerHighest.withValues(alpha: 0.45)),
                    borderRadius: AppSpacing.borderRadiusSM,
                    border: Border.all(
                      color: isCustomHistoricalYear
                          ? (isDark ? AppColors.gold : cs.primary)
                          : cs.outlineVariant.withValues(alpha: 0.3),
                      width: isCustomHistoricalYear ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 14,
                        color: isCustomHistoricalYear
                            ? (isDark ? AppColors.gold : cs.onPrimaryContainer)
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isCustomHistoricalYear ? 'Tahun $_selectedYear' : 'Pilih Tahun',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: isCustomHistoricalYear ? FontWeight.bold : FontWeight.w500,
                          color: isCustomHistoricalYear
                              ? (isDark ? AppColors.gold : cs.onPrimaryContainer)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: isCustomHistoricalYear
                            ? (isDark ? AppColors.gold : cs.onPrimaryContainer)
                            : cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends StatefulWidget {
  final SalesPeriode periode;
  final int? year;
  final ValueChanged<int?>? onYearChanged;
  const _SummaryTab({
    super.key,
    required this.periode,
    this.year,
    this.onYearChanged,
  });

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  final SalesDashboardService _service = SalesDashboardService();
  SalesSummary? _summary;
  List<SalesTrendPoint> _trend = [];
  bool _loadingSummary = false;
  bool _loadingTrend = false;
  String? _errorSummary;
  String? _errorTrend;
  int? _compareYear;
  String _metric = 'omzet'; // 'omzet' | 'order' | 'qty'
  int? _selectedTrendIndex;

  @override
  void initState() {
    super.initState();
    _initCompareYear();
    _loadSummary();
    _loadTrend();
  }

  void _initCompareYear() {
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    if (isYear) {
      final base = widget.year ??
          (widget.periode == SalesPeriode.lastYear
              ? DateTime.now().year - 1
              : DateTime.now().year);
      _compareYear = base - 1;
    } else {
      _compareYear = null;
    }
  }

  @override
  void didUpdateWidget(covariant _SummaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periode != widget.periode || oldWidget.year != widget.year) {
      _initCompareYear();
      _loadSummary();
      _loadTrend();
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _errorSummary = null;
    });
    try {
      final s = await _service.getSummary(widget.periode, year: widget.year);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorSummary = e.toString().replaceFirst('Exception: ', '');
        _loadingSummary = false;
      });
    }
  }

  Future<void> _loadTrend() async {
    setState(() {
      _loadingTrend = true;
      _errorTrend = null;
    });
    try {
      final t = await _service.getTrend(widget.periode,
          compareYear: _compareYear, metric: _metric, year: widget.year);
      if (!mounted) return;
      setState(() {
        _trend = t;
        _loadingTrend = false;
        _selectedTrendIndex = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorTrend = e.toString().replaceFirst('Exception: ', '');
        _loadingTrend = false;
      });
    }
  }

  Future<void> _changeCompareYear(int? year) async {
    setState(() => _compareYear = year);
    await _loadTrend();
  }

  Future<void> _changeMetric(String m) async {
    if (m == _metric || _loadingTrend) return;
    setState(() {
      _metric = m;
      _selectedTrendIndex = null;
    });
    await _loadTrend();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          AppSpacing.paddingMD.copyWith(bottom: ModernBottomNav.clearance(context)),
      children: [
        _buildKpiRow(),
        AppSpacing.gapVerticalMD,
        _buildCompareChip(),
        AppSpacing.gapVerticalSM,
        _buildChart(),
        AppSpacing.gapVerticalLG,
      ],
    );
  }

  Widget _buildCompareChip() {
    final cs = Theme.of(context).colorScheme;
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? DateTime.now().year - 1
            : DateTime.now().year);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (isYear)
          ActionChip(
            label: Text('Tahun: $activeYear'),
            avatar: const Icon(Icons.calendar_today_outlined, size: 15),
            onPressed: _showSelectYearSheet,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ActionChip(
          label: Text(_compareYear == null
              ? 'Bandingkan: —'
              : 'Bandingkan: $_compareYear'),
          avatar: const Icon(Icons.compare_arrows, size: 16),
          onPressed: _showCompareYearSheet,
          backgroundColor: cs.surfaceContainerHighest,
        ),
      ],
    );
  }

  Future<void> _showSelectYearSheet() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(7, (i) => currentYear - i);
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);

    ModernPickerSheet.showFromTuples<int>(
      context: context,
      title: 'Pilih Tahun Penjualan',
      options: years.map((y) {
        String label = 'Tahun $y';
        if (y == currentYear) label += ' (Tahun Ini)';
        if (y == currentYear - 1) label += ' (Tahun Lalu)';
        return (y, label);
      }).toList(),
      selectedItem: activeYear,
      onSelected: (v) {
        if (v != null) {
          widget.onYearChanged?.call(v);
        }
      },
    );
  }

  Future<void> _showCompareYearSheet() async {
    final currentYear = DateTime.now().year;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);
    final years = List.generate(8, (i) => activeYear - 1 - i); // pembanding < activeYear

    ModernPickerSheet.showFromTuples<int?>(
      context: context,
      title: 'Tahun Pembanding',
      options: years.map((y) => (y as int?, 'Tahun $y')).toList(),
      selectedItem: _compareYear,
      showAllOption: true,
      allOptionLabel: 'Tidak ada pembanding',
      allOptionValue: null,
      onSelected: (v) => _changeCompareYear(v),
    );
  }

  Widget _buildKpiRow() {
    if (_loadingSummary) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorSummary != null) {
      return _retryCard(_errorSummary!, _loadSummary);
    }
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    final ts = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(s.periodeLabel,
                  style: ts.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ),
            AppSpacing.gapHorizontalXS,
            Flexible(
              child: Text(
                s.prevLabel.isEmpty ? '' : 'vs ${s.prevLabel}',
                style: ts.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalSM,
        Row(
          children: [
            Expanded(child: _kpiCard('Omzet', s.omzet, s.omzetPrev, isCurrency: true)),
            AppSpacing.gapHorizontalSM,
            Expanded(child: _kpiCard('Order', s.orderCount, s.orderCountPrev)),
            AppSpacing.gapHorizontalSM,
            Expanded(child: _kpiCard('Qty', s.totalQty, s.totalQtyPrev)),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String label, int currentValue, int prevValue,
      {bool isCurrency = false}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOmzet = label.toLowerCase() == 'omzet';
    final valueText = isCurrency
        ? FormatUtils.formatCurrencyCompact(currentValue)
        : FormatUtils.formatNumber(currentValue);
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isOmzet
              ? (isDark ? AppColors.gold.withValues(alpha: 0.45) : cs.primary.withValues(alpha: 0.35))
              : cs.outlineVariant.withValues(alpha: 0.3),
          width: isOmzet ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOmzet
                ? (isDark ? AppColors.gold.withValues(alpha: 0.08) : cs.primary.withValues(alpha: 0.06))
                : AppColors.shadow,
            blurRadius: isOmzet ? 6 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
          AppSpacing.gapVerticalXS,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valueText,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
          ),
          AppSpacing.gapVerticalXS,
          Align(
            alignment: Alignment.centerRight,
            child: _deltaIndicator(currentValue, prevValue, isCurrency: isCurrency),
          ),
        ],
      ),
    );
  }

  /// Indikator naik/turun/baru/stabil untuk KPI card.
  /// Baris pertama: ikon + persentase. Baris kedua: nilai sebelumnya.
  Widget _deltaIndicator(int current, int prev, {bool isCurrency = false}) {
    final cs = Theme.of(context).colorScheme;
    final prevText = isCurrency
        ? FormatUtils.formatCurrencyCompact(prev)
        : FormatUtils.formatNumber(prev);
    if (prev == 0) {
      // Tidak ada data pembanding → hindari div-by-zero.
      return _pill(Icons.fiber_new, 'Baru', cs.outline);
    }
    final delta = current - prev;
    final pct = (delta.abs() / prev * 100).round();
    final Color color;
    final IconData icon;
    if (delta > 0) {
      color = AppColors.success;
      icon = Icons.arrow_upward;
    } else if (delta < 0) {
      color = AppColors.error;
      icon = Icons.arrow_downward;
    } else {
      color = cs.outline;
      icon = Icons.arrow_forward;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _pill(icon, '$pct%', color),
        const SizedBox(height: 2),
        Text(
          'dari $prevText',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(text,
            style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChart() {
    if (_loadingTrend) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (_errorTrend != null) {
      return SizedBox(height: 200, child: _retryCard(_errorTrend!, _loadTrend));
    }
    if (_trend.isEmpty) {
      return const SizedBox(
          height: 200, child: Center(child: Text('Tidak ada data trend.')));
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasCompare = _compareYear != null && _trend.any((p) => p.valuePrev != null);

    final currentSpots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < _trend.length; i++) {
      final v = _trend[i].value.toDouble();
      currentSpots.add(FlSpot(i.toDouble(), v));
      if (v > maxY) maxY = v;
    }

    final prevSpots = <FlSpot>[];
    if (hasCompare) {
      for (var i = 0; i < _trend.length; i++) {
        final v = (_trend[i].valuePrev ?? 0).toDouble();
        prevSpots.add(FlSpot(i.toDouble(), v));
        if (v > maxY) maxY = v;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metricColor = _metricColor;
    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: currentSpots,
        isCurved: true,
        color: metricColor,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final isSelected = index == _selectedTrendIndex;
            return FlDotCirclePainter(
              radius: isSelected ? 5.5 : (_trend.length <= 15 ? 3.0 : 1.5),
              color: isSelected ? cs.primary : metricColor,
              strokeWidth: isSelected ? 2 : 1,
              strokeColor: isDark ? AppColors.darkSurface : Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: metricColor.withValues(alpha: 0.15),
        ),
      ),
    ];
    if (hasCompare) {
      lineBars.add(LineChartBarData(
        spots: prevSpots,
        isCurved: true,
        color: cs.outline,
        barWidth: 2,
        dashArray: const [4, 4],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final isSelected = index == _selectedTrendIndex;
            return FlDotCirclePainter(
              radius: isSelected ? 4.5 : (_trend.length <= 15 ? 2.5 : 1.0),
              color: cs.outline,
              strokeWidth: 1,
              strokeColor: isDark ? AppColors.darkSurface : Colors.white,
            );
          },
        ),
      ));
    }

    final double xInterval = _trend.length > 20
        ? 5
        : (_trend.length > 10 ? 2 : 1);
    final double yInterval = maxY > 0 ? (maxY / 3) : 1;

    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tren ${_metricLabel(_metric)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          AppSpacing.gapVerticalXS,
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              _metricChip('Omzet', 'omzet'),
              _metricChip('Order', 'order'),
              _metricChip('Qty', 'qty'),
            ],
          ),
          if (hasCompare) ...[
            AppSpacing.gapVerticalXS,
            Row(children: [
              ExcludeSemantics(
                child: Icon(Icons.circle, size: 12, color: metricColor, semanticLabel: null),
              ),
              AppSpacing.gapHorizontalXS,
              Text('Periode ini', style: AppTypography.labelSmall),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Icon(Icons.linear_scale, size: 12, color: cs.outline, semanticLabel: null),
              ),
              AppSpacing.gapHorizontalXS,
              Text('$_compareYear', style: AppTypography.labelSmall),
            ]),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY == 0 ? 1 : maxY * 1.15,
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppColors.darkSurfaceVariant : AppColors.primary,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((ts) {
                        final idx = ts.spotIndex;
                        if (idx < 0 || idx >= _trend.length) return null;
                        final point = _trend[idx];
                        final isCompare = ts.barIndex == 1;
                        final val = isCompare ? (point.valuePrev ?? 0) : point.value;
                        final prefix = isCompare ? '$_compareYear: ' : '';
                        return LineTooltipItem(
                          '$prefix${_fmtMetric(val)}',
                          TextStyle(
                            color: isDark ? AppColors.darkOnSurface : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text: '\n(${point.label})',
                              style: TextStyle(
                                color: (isDark ? AppColors.darkOnSurface : Colors.white)
                                    .withValues(alpha: 0.75),
                                fontSize: 9.5,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (event is FlTapUpEvent ||
                        event is FlPanUpdateEvent ||
                        event is FlTapDownEvent) {
                      if (touchResponse != null &&
                          touchResponse.lineBarSpots != null &&
                          touchResponse.lineBarSpots!.isNotEmpty) {
                        final idx = touchResponse.lineBarSpots!.first.spotIndex;
                        if (idx >= 0 && idx < _trend.length && idx != _selectedTrendIndex) {
                          setState(() {
                            _selectedTrendIndex = idx;
                          });
                        }
                      }
                    }
                  },
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.3),
                    strokeWidth: 0.8,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Waktu / Periode',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 9.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    axisNameSize: 16,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: xInterval,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _trend.length || value != idx.toDouble()) {
                          return const SizedBox.shrink();
                        }
                        final isSelected = idx == _selectedTrendIndex;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _trend[idx].label,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9.5,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? metricColor : cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _metricLabel(_metric),
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 9.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    axisNameSize: 14,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > maxY * 1.05) {
                          return const SizedBox.shrink();
                        }
                        final String text;
                        if (_metric == 'omzet') {
                          text = FormatUtils.formatCurrencyCompact(value.round());
                        } else {
                          text = FormatUtils.formatNumber(value.round());
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            text,
                            textAlign: TextAlign.right,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
                      width: 1,
                    ),
                    left: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
                      width: 1,
                    ),
                  ),
                ),
                lineBarsData: lineBars,
              ),
            ),
          ),
          if (_selectedTrendIndex != null && _selectedTrendIndex! < _trend.length) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: metricColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: AppSpacing.borderRadiusSM,
                border: Border.all(
                  color: metricColor.withValues(alpha: isDark ? 0.4 : 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded, size: 16, color: metricColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
                        children: [
                          TextSpan(
                            text: '${_trend[_selectedTrendIndex!].label}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: _fmtMetric(_trend[_selectedTrendIndex!].value),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: metricColor,
                              fontSize: 13,
                            ),
                          ),
                          if (hasCompare) ...[
                            TextSpan(
                              text:
                                  '  (Tahun lalu $_compareYear: ${_fmtMetric(_trend[_selectedTrendIndex!].valuePrev ?? 0)})',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedTrendIndex = null),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              '* Sentuh titik pada grafik untuk melihat rincian angka',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ----- Helper metric (Omzet/Order/Qty) untuk chart -----

  Color get _metricColor {
    final cs = Theme.of(context).colorScheme;
    switch (_metric) {
      case 'order':
        return cs.primary;
      case 'qty':
        return AppColors.success;
      default:
        return cs.secondary; // 'omzet'
    }
  }

  String _metricLabel(String metric) {
    switch (metric) {
      case 'order':
        return 'Order';
      case 'qty':
        return 'Qty';
      default:
        return 'Omzet';
    }
  }

  String _fmtMetric(int v) {
    switch (_metric) {
      case 'omzet':
        return FormatUtils.formatCurrencyCompact(v);
      case 'order':
      case 'qty':
      default:
        return FormatUtils.formatNumber(v);
    }
  }

  Widget _metricChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _metric == value,
      onSelected: _loadingTrend ? null : (_) => _changeMetric(value),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity(horizontal: -3, vertical: -3),
    );
  }

  Widget _retryCard(String msg, VoidCallback onRetry) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          children: [
            Text(msg, textAlign: TextAlign.center),
            AppSpacing.gapVerticalSM,
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  final SalesPeriode periode;
  final int? year;
  final ValueChanged<int?>? onYearChanged;
  const _ProductsTab({
    super.key,
    required this.periode,
    this.year,
    this.onYearChanged,
  });

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final SalesDashboardService _service = SalesDashboardService();
  final TextEditingController _searchController = TextEditingController();

  List<SalesProductItem> _items = [];
  List<SalesCategorySummaryItem> _categorySummary = [];
  String? _selectedCategory;
  SalesProductMeta? _meta;
  ProductSort _sort = ProductSort.qty;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  final int _perPage = 50;
  int? _compareYear;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initCompareYear();
    _searchController.addListener(_onSearchChanged);
    _load(reset: true);
  }

  void _initCompareYear() {
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    if (isYear) {
      final base = widget.year ??
          (widget.periode == SalesPeriode.lastYear
              ? DateTime.now().year - 1
              : DateTime.now().year);
      _compareYear = base - 1;
    } else {
      _compareYear = null;
    }
  }

  @override
  void didUpdateWidget(covariant _ProductsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periode != widget.periode || oldWidget.year != widget.year) {
      _initCompareYear();
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      _page = 1;
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final page = reset ? 1 : _page + 1;
      final isYear = widget.periode == SalesPeriode.year ||
          widget.periode == SalesPeriode.lastYear ||
          widget.year != null;
      final result = await _service.getProducts(
        widget.periode,
        page: page,
        perPage: _perPage,
        sort: _sort,
        compareYear: isYear ? _compareYear : null,
        year: widget.year,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = result.items;
          _categorySummary = result.categorySummary;
        } else {
          _items = [..._items, ...result.items];
          _page = page;
        }
        _meta = result.meta;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _changeCompareYear(int? year) async {
    setState(() => _compareYear = year);
    await _load(reset: true);
  }

  Future<void> _showCompareYearSheet() async {
    final currentYear = DateTime.now().year;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);
    final years = List.generate(8, (i) => activeYear - 1 - i);

    ModernPickerSheet.showFromTuples<int?>(
      context: context,
      title: 'Tahun Pembanding Produk',
      options: years.map((y) => (y as int?, 'Tahun $y')).toList(),
      selectedItem: _compareYear,
      showAllOption: true,
      allOptionLabel: 'Tidak ada pembanding',
      allOptionValue: null,
      onSelected: (v) => _changeCompareYear(v),
    );
  }

  Future<void> _showSelectYearSheet() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(7, (i) => currentYear - i);
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);

    ModernPickerSheet.showFromTuples<int>(
      context: context,
      title: 'Pilih Tahun Penjualan',
      options: years.map((y) {
        String label = 'Tahun $y';
        if (y == currentYear) label += ' (Tahun Ini)';
        if (y == currentYear - 1) label += ' (Tahun Lalu)';
        return (y, label);
      }).toList(),
      selectedItem: activeYear,
      onSelected: (v) {
        if (v != null) {
          widget.onYearChanged?.call(v);
        }
      },
    );
  }

  List<SalesProductItem> get _filteredItems {
    var list = _items;
    if (_selectedCategory != null) {
      list = list.where((it) => it.categoryName == _selectedCategory).toList();
    }
    if (_searchQuery.isEmpty) return list;
    return list.where((it) {
      final name = (it.productName ?? '').toLowerCase();
      final id = it.productId.toString();
      final cat = (it.categoryName ?? '').toLowerCase();
      return name.contains(_searchQuery) || id.contains(_searchQuery) || cat.contains(_searchQuery);
    }).toList();
  }

  int get _maxMetricValue {
    if (_items.isEmpty) return 1;
    if (_sort == ProductSort.revenue) {
      final max = _items.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
      return max <= 0 ? 1 : max;
    } else {
      final max = _items.map((e) => e.qty).reduce((a, b) => a > b ? a : b);
      return max <= 0 ? 1 : max;
    }
  }

  int get _totalLoadedQty => _items.fold(0, (sum, it) => sum + it.qty);
  int get _totalLoadedQtyPrev => _items.fold(0, (sum, it) => sum + it.qtyPrev);
  int get _totalLoadedRevenue => _items.fold(0, (sum, it) => sum + it.revenue);
  int get _totalLoadedRevenuePrev => _items.fold(0, (sum, it) => sum + it.revenuePrev);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeletonView();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              AppSpacing.gapVerticalMD,
              Text(_error!, textAlign: TextAlign.center),
              AppSpacing.gapVerticalMD,
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: () => _load(reset: true),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredItems;

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding:
            AppSpacing.paddingMD.copyWith(bottom: ModernBottomNav.clearance(context)),
        children: [
          _buildCompareBanner(),
          AppSpacing.gapVerticalSM,
          _buildSummaryCards(),
          if (_categorySummary.isNotEmpty) ...[
            AppSpacing.gapVerticalMD,
            _buildCategoryBreakdownBar(),
          ],
          AppSpacing.gapVerticalMD,
          _buildSearchAndSortBar(),
          AppSpacing.gapVerticalMD,
          if (filtered.isEmpty)
            _buildEmptyState()
          else ...[
            ...List.generate(filtered.length, (i) {
              return _buildProductCard(filtered[i], i);
            }),
            _buildLoadMoreRow(),
          ],
          AppSpacing.gapVerticalLG,
        ],
      ),
    );
  }

  /// Banner indikator periode & pembanding (misal Tahun ini vs Tahun lalu)
  Widget _buildCompareBanner() {
    final cs = Theme.of(context).colorScheme;
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? DateTime.now().year - 1
            : DateTime.now().year);
    final periodeLabel = widget.year != null ? 'Tahun ${widget.year}' : widget.periode.label;
    final compareText = isYear
        ? (_compareYear != null ? 'vs Tahun $_compareYear' : 'Tanpa pembanding')
        : (_meta?.prevLabel.isNotEmpty == true ? 'vs ${_meta!.prevLabel}' : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, size: 16, color: cs.primary),
          AppSpacing.gapHorizontalSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Performa Produk ($periodeLabel)',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                ),
                if (compareText.isNotEmpty)
                  Text(
                    compareText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (isYear) ...[
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 14),
              label: Text(
                '$activeYear',
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: _showSelectYearSheet,
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.compare_arrows, size: 14),
              label: Text(
                _compareYear != null ? '$_compareYear' : 'Pilih',
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: _showCompareYearSheet,
            ),
          ],
        ],
      ),
    );
  }

  /// Strip KPI ringkasan 3 metrik produk (SKU, Omzet, Qty)
  Widget _buildSummaryCards() {
    final totalSku = _meta?.total ?? _items.length;
    return Row(
      children: [
        Expanded(
          child: _summaryStatCard(
            label: 'VARIAN SKU',
            valueText: '$totalSku',
            icon: Icons.category_outlined,
            deltaWidget: Text(
              '${_items.length} termuat',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: _summaryStatCard(
            label: 'TOTAL OMZET',
            valueText: FormatUtils.formatCurrencyCompact(_totalLoadedRevenue),
            icon: Icons.monetization_on_outlined,
            deltaWidget: _buildDeltaBadge(
              _totalLoadedRevenue,
              _totalLoadedRevenuePrev,
              isCurrency: true,
            ),
          ),
        ),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: _summaryStatCard(
            label: 'TOTAL QTY',
            valueText: FormatUtils.formatNumber(_totalLoadedQty),
            icon: Icons.inventory_2_outlined,
            deltaWidget: _buildDeltaBadge(
              _totalLoadedQty,
              _totalLoadedQtyPrev,
              isCurrency: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryStatCard({
    required String label,
    required String valueText,
    required IconData icon,
    required Widget deltaWidget,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.secondary),
              AppSpacing.gapHorizontalXS,
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalXS,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          AppSpacing.gapVerticalXS,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: deltaWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_outline, size: 14, color: AppColors.secondary),
                  AppSpacing.gapHorizontalXS,
                  Text(
                    'OMZET PER KATEGORI PRODUK',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              if (_selectedCategory != null)
                InkWell(
                  onTap: () => setState(() => _selectedCategory = null),
                  child: Text(
                    'Reset filter',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('Semua (${FormatUtils.formatCurrencyCompact(_totalLoadedRevenue)})'),
                    selected: _selectedCategory == null,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                    selectedColor: isDark
                        ? AppColors.secondary.withValues(alpha: 0.3)
                        : cs.primaryContainer,
                  ),
                ),
                ..._categorySummary.map((cat) {
                  final isSelected = _selectedCategory == cat.categoryName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: isSelected
                          ? null
                          : CircleAvatar(
                              radius: 4,
                              backgroundColor: AppColors.gold,
                            ),
                      label: Text('${cat.categoryName}: ${FormatUtils.formatCurrencyCompact(cat.revenue)} (${cat.percentage.toStringAsFixed(0)}%)'),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          _selectedCategory = val ? cat.categoryName : null;
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                      selectedColor: isDark
                          ? AppColors.secondary.withValues(alpha: 0.3)
                          : cs.primaryContainer,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Search bar & sort filter chips
  Widget _buildSearchAndSortBar() {
    final cs = Theme.of(context).colorScheme;
    final total = _meta?.total ?? _items.length;
    final displayed = _filteredItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchTextField(
          controller: _searchController,
          hintText: 'Cari nama, ID, atau kategori...',
          onCleared: () {
            setState(() => _searchQuery = '');
          },
        ),
        AppSpacing.gapVerticalSM,
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Urutan:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    AppSpacing.gapHorizontalSM,
                    ChoiceChip(
                      avatar: Icon(
                        Icons.numbers,
                        size: 14,
                        color: _sort == ProductSort.qty ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                      ),
                      label: const Text('Qty'),
                      selected: _sort == ProductSort.qty,
                      onSelected: (_) {
                        setState(() => _sort = ProductSort.qty);
                        _load(reset: true);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      avatar: Icon(
                        Icons.payments_outlined,
                        size: 14,
                        color: _sort == ProductSort.revenue ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                      ),
                      label: const Text('Omzet'),
                      selected: _sort == ProductSort.revenue,
                      onSelected: (_) {
                        setState(() => _sort = ProductSort.revenue);
                        _load(reset: true);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.gapHorizontalSM,
            Text(
              '$displayed${total > 0 ? ' / $total' : ''}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  /// Kartu Produk Modern dengan Badge Ranking, Metrik YoY & Share Bar
  Widget _buildProductCard(SalesProductItem item, int index) {
    final cs = Theme.of(context).colorScheme;
    final rank = index + 1;
    final isTop1 = rank == 1;
    final isTop2 = rank == 2;
    final isTop3 = rank == 3;

    // Kalkulasi share relatif terhadap produk #1
    final metricValue = _sort == ProductSort.revenue ? item.revenue : item.qty;
    final shareRatio = (metricValue / _maxMetricValue).clamp(0.0, 1.0);
    final sharePct = (shareRatio * 100).round();

    // Rata-rata harga per unit
    final asp = item.qty > 0 ? (item.revenue / item.qty).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isTop1
              ? AppColors.secondary.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.35),
          width: isTop1 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isTop1
                ? AppColors.secondary.withValues(alpha: 0.12)
                : AppColors.shadow,
            blurRadius: isTop1 ? 8 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Atas: Badge Ranking, Nama Produk, Unit Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildRankBadge(rank, isTop1, isTop2, isTop3),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Produk #${item.productId}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (asp > 0)
                        Text(
                          'Rata-rata @ ${FormatUtils.formatCurrency(asp)}${item.unit != null ? ' / ${item.unit}' : ''}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.categoryName != null && item.categoryName!.isNotEmpty) ...[
                  AppSpacing.gapHorizontalXS,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.6),
                      borderRadius: AppSpacing.borderRadiusXS,
                    ),
                    child: Text(
                      item.categoryName!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
                if (item.unit != null) ...[
                  AppSpacing.gapHorizontalXS,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                      borderRadius: AppSpacing.borderRadiusXS,
                    ),
                    child: Text(
                      item.unit!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Baris Metrik: Omzet (Kiri) & Kuantitas (Kanan) dengan Delta YoY
            Row(
              children: [
                // Kolom Omzet
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, size: 12, color: AppColors.secondary),
                          AppSpacing.gapHorizontalXS,
                          Text(
                            'OMZET',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          FormatUtils.formatCurrency(item.revenue),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildDeltaBadge(
                        item.revenue,
                        item.revenuePrev,
                        isCurrency: true,
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 38,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),

                // Kolom Qty
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 12, color: cs.primary),
                          AppSpacing.gapHorizontalXS,
                          Text(
                            'KUANTITAS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${FormatUtils.formatNumber(item.qty)} ${item.unit ?? ''}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildDeltaBadge(
                        item.qty,
                        item.qtyPrev,
                        isCurrency: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Visual Share Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _sort == ProductSort.revenue
                          ? 'Pangsa omzet vs produk teratas'
                          : 'Pangsa qty vs produk teratas',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$sharePct%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _sort == ProductSort.revenue
                            ? AppColors.secondary
                            : cs.primary,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapVerticalXS,
                ClipRRect(
                  borderRadius: AppSpacing.borderRadiusXS,
                  child: LinearProgressIndicator(
                    value: shareRatio,
                    minHeight: 5,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _sort == ProductSort.revenue
                          ? AppColors.secondary
                          : cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Badge Ranking: Podium Emas (#1), Perak (#2), Perunggu (#3), dan Standar (#4+)
  Widget _buildRankBadge(int rank, bool isTop1, bool isTop2, bool isTop3) {
    if (isTop1) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gold, AppColors.inversePrimary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.inversePrimary.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, size: 14, color: Colors.white),
              Text(
                '1',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isTop2) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.outlineVariant, AppColors.outline, AppColors.onSurfaceVariant],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '#2',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (isTop3) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.secondaryContainer, AppColors.secondary, AppColors.onSecondaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '#3',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Indikator Delta YoY (+X% hijau, -X% merah, Baru abu-abu)
  Widget _buildDeltaBadge(int current, int prev, {bool isCurrency = false}) {
    final cs = Theme.of(context).colorScheme;
    final prevText = isCurrency
        ? FormatUtils.formatCurrencyCompact(prev)
        : FormatUtils.formatNumber(prev);

    if (prev == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: AppSpacing.borderRadiusXS,
            ),
            child: Text(
              'Baru',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
            ),
          ),
        ],
      );
    }

    final delta = current - prev;
    final pct = (delta.abs() / prev * 100).round();
    final isUp = delta > 0;
    final isDown = delta < 0;
    final Color color = isUp
        ? AppColors.success
        : isDown
            ? AppColors.error
            : cs.outline;
    final icon = isUp
        ? Icons.arrow_upward
        : isDown
            ? Icons.arrow_downward
            : Icons.arrow_forward;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '$pct%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
          ),
          AppSpacing.gapHorizontalXS,
          Text(
            'vs $prevText',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(
          icon: Icons.search_off,
          title: 'Produk Tidak Ditemukan',
          subtitle: 'Tidak ada produk yang cocok dengan "$_searchQuery"',
          action: FilledButton.tonal(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            child: const Text('Hapus Pencarian'),
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Tidak Ada Produk Terjual',
        subtitle: 'Belum ada transaksi produk terkirim pada periode ini.',
      ),
    );
  }

  Widget _buildSkeletonView() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: AppSpacing.paddingMD,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Skeleton banner
        SkeletonLoading(height: 36, borderRadius: AppSpacing.borderRadiusSM),
        AppSpacing.gapVerticalSM,
        // Skeleton KPI strip
        Row(
          children: [
            Expanded(child: SkeletonLoading(height: 70, borderRadius: AppSpacing.borderRadiusMD)),
            AppSpacing.gapHorizontalSM,
            Expanded(child: SkeletonLoading(height: 70, borderRadius: AppSpacing.borderRadiusMD)),
            AppSpacing.gapHorizontalSM,
            Expanded(child: SkeletonLoading(height: 70, borderRadius: AppSpacing.borderRadiusMD)),
          ],
        ),
        AppSpacing.gapVerticalMD,
        // Skeleton search bar
        SkeletonLoading(height: 48, borderRadius: AppSpacing.borderRadiusMD),
        AppSpacing.gapVerticalMD,
        // 4 Skeleton product cards
        ...List.generate(4, (_) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: AppSpacing.borderRadiusMD,
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonAvatar(size: 32),
                    const SizedBox(width: 10),
                    const Expanded(child: SkeletonText(lines: 2, height: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: SkeletonText(lines: 2, height: 10)),
                    const SizedBox(width: 20),
                    const Expanded(child: SkeletonText(lines: 2, height: 10)),
                  ],
                ),
                AppSpacing.gapVerticalSM,
                SkeletonLoading(height: 6, borderRadius: AppSpacing.borderRadiusXS),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoadMoreRow() {
    if (_meta == null || !_meta!.hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: FilledButton.tonal(
          onPressed: _isLoadingMore ? null : () => _load(reset: false),
          child: _isLoadingMore
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Muat lebih banyak (${_meta!.currentPage + 1}/${_meta!.lastPage})'),
        ),
      ),
    );
  }
}

class _ChannelsTab extends StatefulWidget {
  final SalesPeriode periode;
  final int? year;
  final ValueChanged<int?>? onYearChanged;
  const _ChannelsTab({
    super.key,
    required this.periode,
    this.year,
    this.onYearChanged,
  });

  @override
  State<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<_ChannelsTab> {
  final SalesDashboardService _service = SalesDashboardService();
  SalesChannelsResult? _result;
  bool _isLoading = false;
  String? _error;
  int? _compareYear;

  @override
  void initState() {
    super.initState();
    _initCompareYear();
    _load();
  }

  void _initCompareYear() {
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    if (isYear) {
      final base = widget.year ??
          (widget.periode == SalesPeriode.lastYear
              ? DateTime.now().year - 1
              : DateTime.now().year);
      _compareYear = base - 1;
    } else {
      _compareYear = null;
    }
  }

  @override
  void didUpdateWidget(covariant _ChannelsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periode != widget.periode || oldWidget.year != widget.year) {
      _initCompareYear();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final isYear = widget.periode == SalesPeriode.year ||
          widget.periode == SalesPeriode.lastYear ||
          widget.year != null;
      final res = await _service.getChannels(
        widget.periode,
        compareYear: isYear ? _compareYear : null,
        year: widget.year,
      );
      if (!mounted) return;
      setState(() {
        _result = res;
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

  Future<void> _changeCompareYear(int? year) async {
    setState(() => _compareYear = year);
    await _load();
  }

  Future<void> _showCompareYearSheet() async {
    final currentYear = DateTime.now().year;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);
    final years = List.generate(8, (i) => activeYear - 1 - i);

    ModernPickerSheet.showFromTuples<int?>(
      context: context,
      title: 'Tahun Pembanding Channel',
      options: years.map((y) => (y as int?, 'Tahun $y')).toList(),
      selectedItem: _compareYear,
      showAllOption: true,
      allOptionLabel: 'Tidak ada pembanding',
      allOptionValue: null,
      onSelected: (v) => _changeCompareYear(v),
    );
  }

  Future<void> _showSelectYearSheet() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(7, (i) => currentYear - i);
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);

    ModernPickerSheet.showFromTuples<int>(
      context: context,
      title: 'Pilih Tahun Penjualan',
      options: years.map((y) {
        String label = 'Tahun $y';
        if (y == currentYear) label += ' (Tahun Ini)';
        if (y == currentYear - 1) label += ' (Tahun Lalu)';
        return (y, label);
      }).toList(),
      selectedItem: activeYear,
      onSelected: (v) {
        if (v != null) {
          widget.onYearChanged?.call(v);
        }
      },
    );
  }

  Color _colorFor(String channel) {
    switch (channel) {
      case '3':
        return AppColors.secondary; // Gold (Online)
      case '1':
        return AppColors.primary; // Blue (Direct)
      case '2':
        return const Color(0xFF10B981); // Emerald Green (Employee)
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  String _subtitleFor(String channel) {
    switch (channel) {
      case '3':
        return 'Shopee, Tokopedia, TikTok, Web';
      case '1':
        return 'Penjualan Langsung & Outlet';
      case '2':
        return 'Penjualan oleh Sales / Tim';
      default:
        return 'Channel Penjualan';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              AppSpacing.gapVerticalMD,
              Text(_error!, textAlign: TextAlign.center),
              AppSpacing.gapVerticalMD,
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _result?.items ?? [];
    final totalOmzet = _result?.totalOmzet ?? 0;

    if (items.isEmpty || totalOmzet == 0) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: EmptyState(
            icon: Icons.storefront_outlined,
            title: 'Belum Ada Penjualan Channel',
            subtitle: 'Belum ada data transaksi yang tercatat di periode ${widget.periode.label}',
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppSpacing.paddingMD.copyWith(bottom: ModernBottomNav.clearance(context)),
        children: [
          _buildCompareBanner(),
          AppSpacing.gapVerticalSM,
          _buildSummaryCards(),
          AppSpacing.gapVerticalMD,
          _buildPieCard(),
          AppSpacing.gapVerticalMD,
          ...items.map(_buildChannelRow),
          AppSpacing.gapVerticalLG,
        ],
      ),
    );
  }

  Widget _buildCompareBanner() {
    final cs = Theme.of(context).colorScheme;
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? DateTime.now().year - 1
            : DateTime.now().year);
    final periodeLabel = widget.year != null ? 'Tahun ${widget.year}' : widget.periode.label;
    final compareText = isYear
        ? (_compareYear != null ? 'vs Tahun $_compareYear' : 'Tanpa pembanding')
        : (_result?.prevLabel.isNotEmpty == true ? 'vs ${_result!.prevLabel}' : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.pie_chart_outline, size: 16, color: cs.primary),
          AppSpacing.gapHorizontalSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Performa Channel Penjualan ($periodeLabel)',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                ),
                if (compareText.isNotEmpty)
                  Text(
                    compareText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (isYear) ...[
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 14),
              label: Text(
                '$activeYear',
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: _showSelectYearSheet,
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.compare_arrows, size: 14),
              label: Text(
                _compareYear != null ? '$_compareYear' : 'Pilih',
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: _showCompareYearSheet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final res = _result;
    final totalRevenue = res?.totalOmzet ?? 0;
    final totalRevenuePrev = res?.totalOmzetPrev ?? 0;
    final totalQty = res?.totalQty ?? 0;
    final totalQtyPrev = res?.totalQtyPrev ?? 0;
    final totalOrders = res?.totalOrders ?? 0;
    final totalOrdersPrev = res?.totalOrdersPrev ?? 0;

    return Row(
      children: [
        Expanded(
          child: _summaryStatCard(
            label: 'TOTAL OMZET',
            valueText: FormatUtils.formatCurrencyCompact(totalRevenue),
            icon: Icons.monetization_on_outlined,
            deltaWidget: _buildDeltaBadge(
              totalRevenue,
              totalRevenuePrev,
              isCurrency: true,
            ),
          ),
        ),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: _summaryStatCard(
            label: 'TOTAL QTY',
            valueText: FormatUtils.formatNumber(totalQty),
            icon: Icons.inventory_2_outlined,
            deltaWidget: _buildDeltaBadge(
              totalQty,
              totalQtyPrev,
              isCurrency: false,
            ),
          ),
        ),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: _summaryStatCard(
            label: 'TOTAL ORDER',
            valueText: FormatUtils.formatNumber(totalOrders),
            icon: Icons.receipt_long_outlined,
            deltaWidget: _buildDeltaBadge(
              totalOrders,
              totalOrdersPrev,
              isCurrency: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryStatCard({
    required String label,
    required String valueText,
    required IconData icon,
    required Widget deltaWidget,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.secondary),
              AppSpacing.gapHorizontalXS,
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalXS,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          AppSpacing.gapVerticalXS,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: deltaWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildPieCard() {
    final cs = Theme.of(context).colorScheme;
    final items = (_result?.items ?? []).where((it) => it.omzet > 0).toList();
    final totalOmzet = _result?.totalOmzet ?? 1;

    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart, size: 16, color: AppColors.secondary),
                  AppSpacing.gapHorizontalXS,
                  Text(
                    'PANGSA OMZET PER CHANNEL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Text(
                '${items.length} Channel',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalMD,
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 55,
                    sections: items.map((item) {
                      final color = _colorFor(item.channel);
                      return PieChartSectionData(
                        value: item.omzet.toDouble(),
                        color: color,
                        title: '${item.percentage.toStringAsFixed(0)}%',
                        radius: 40,
                        titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Omzet',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      FormatUtils.formatCurrencyCompact(totalOmzet),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapVerticalMD,
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: items.map((item) {
              final color = _colorFor(item.channel);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.channelLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${item.percentage.toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow(SalesChannelItem item) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _colorFor(item.channel);
    final totalOmzet = _result?.totalOmzet ?? 1;
    final shareRatio = totalOmzet > 0 ? (item.omzet / totalOmzet).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: AppSpacing.paddingMD,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.channelLabel,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: AppSpacing.borderRadiusXS,
                          ),
                          child: Text(
                            '${item.percentage.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleFor(item.channel),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${FormatUtils.formatNumber(item.orderCount)} order · ${FormatUtils.formatNumber(item.qty)} pcs terjual',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.formatCurrencyCompact(item.omzet),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          const Divider(height: 1),
          AppSpacing.gapVerticalSM,

          // YoY Delta Row: YoY Omzet vs YoY Qty
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YoY Omzet',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildDeltaBadge(
                      item.omzet,
                      item.omzetPrev,
                      isCurrency: true,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YoY Kuantitas',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildDeltaBadge(
                      item.qty,
                      item.qtyPrev,
                      isCurrency: false,
                    ),
                  ],
                ),
              ),
            ],
          ),

          AppSpacing.gapVerticalSM,

          // Visual Progress Bar
          ClipRRect(
            borderRadius: AppSpacing.borderRadiusXS,
            child: LinearProgressIndicator(
              value: shareRatio,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaBadge(int current, int prev, {bool isCurrency = false}) {
    final cs = Theme.of(context).colorScheme;
    final prevText = isCurrency
        ? FormatUtils.formatCurrencyCompact(prev)
        : FormatUtils.formatNumber(prev);

    if (prev == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: AppSpacing.borderRadiusXS,
            ),
            child: Text(
              'Baru',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final delta = current - prev;
    final pct = (delta.abs() / prev * 100).round();
    final isUp = delta > 0;
    final isDown = delta < 0;
    final Color color = isUp
        ? AppColors.success
        : isDown
            ? AppColors.error
            : cs.outline;
    final icon = isUp
        ? Icons.arrow_upward
        : isDown
            ? Icons.arrow_downward
            : Icons.arrow_forward;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '$pct%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapHorizontalXS,
          Text(
            'vs $prevText',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

enum CategorySort { revenue, qty }

class _CategoriesTab extends StatefulWidget {
  final SalesPeriode periode;
  final int? year;
  final ValueChanged<int?>? onYearChanged;
  const _CategoriesTab({
    super.key,
    required this.periode,
    this.year,
    this.onYearChanged,
  });

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final SalesDashboardService _service = SalesDashboardService();
  final TextEditingController _searchController = TextEditingController();

  SalesCategoriesResult? _result;
  bool _isLoading = false;
  String? _error;
  int? _compareYear;
  CategorySort _sort = CategorySort.revenue;
  String _searchQuery = '';
  int _touchedPieIndex = -1;
  final Set<int?> _expandedCategoryIds = <int?>{};

  static const List<Color> _categoryColors = [
    Color(0xFFD4AF37), // Gold Sagansa
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF59E0B), // Amber
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF6366F1), // Indigo
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
    Color(0xFF64748B), // Slate
  ];

  @override
  void initState() {
    super.initState();
    _initCompareYear();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  void _initCompareYear() {
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    if (isYear) {
      final base = widget.year ??
          (widget.periode == SalesPeriode.lastYear
              ? DateTime.now().year - 1
              : DateTime.now().year);
      _compareYear = base - 1;
    } else {
      _compareYear = null;
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void didUpdateWidget(covariant _CategoriesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periode != widget.periode || oldWidget.year != widget.year) {
      _initCompareYear();
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final isYear = widget.periode == SalesPeriode.year ||
          widget.periode == SalesPeriode.lastYear ||
          widget.year != null;
      final res = await _service.getCategories(
        widget.periode,
        compareYear: isYear ? _compareYear : null,
        year: widget.year,
      );
      if (!mounted) return;
      setState(() {
        _result = res;
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

  Future<void> _changeCompareYear(int? year) async {
    setState(() => _compareYear = year);
    await _load();
  }

  Future<void> _showCompareYearSheet() async {
    final currentYear = DateTime.now().year;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);
    final years = List.generate(8, (i) => activeYear - 1 - i);

    ModernPickerSheet.showFromTuples<int?>(
      context: context,
      title: 'Tahun Pembanding Kategori',
      options: years.map((y) => (y as int?, 'Tahun $y')).toList(),
      selectedItem: _compareYear,
      showAllOption: true,
      allOptionLabel: 'Tidak ada pembanding',
      allOptionValue: null,
      onSelected: (v) => _changeCompareYear(v),
    );
  }

  Future<void> _showSelectYearSheet() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(7, (i) => currentYear - i);
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? currentYear - 1
            : currentYear);

    ModernPickerSheet.showFromTuples<int>(
      context: context,
      title: 'Pilih Tahun Penjualan',
      options: years.map((y) {
        String label = 'Tahun $y';
        if (y == currentYear) label += ' (Tahun Ini)';
        if (y == currentYear - 1) label += ' (Tahun Lalu)';
        return (y, label);
      }).toList(),
      selectedItem: activeYear,
      onSelected: (v) {
        if (v != null) {
          widget.onYearChanged?.call(v);
        }
      },
    );
  }

  List<SalesCategoryItem> get _sortedAndFilteredItems {
    if (_result == null) return [];
    var list = List<SalesCategoryItem>.from(_result!.items);

    // Sort
    list.sort((a, b) {
      if (_sort == CategorySort.revenue) {
        return b.revenue.compareTo(a.revenue);
      } else {
        return b.qty.compareTo(a.qty);
      }
    });

    // Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final matchesCat = item.categoryName.toLowerCase().contains(_searchQuery);
        final matchesProduct = item.topProducts.any(
          (p) => p.productName.toLowerCase().contains(_searchQuery),
        );
        return matchesCat || matchesProduct;
      }).toList();
    }

    return list;
  }

  Color _colorForIndex(int index) {
    return _categoryColors[index % _categoryColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeletonView();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              AppSpacing.gapVerticalMD,
              Text(_error!, textAlign: TextAlign.center),
              AppSpacing.gapVerticalMD,
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _sortedAndFilteredItems;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppSpacing.paddingMD.copyWith(bottom: ModernBottomNav.clearance(context)),
        children: [
          _buildCompareBanner(),
          AppSpacing.gapVerticalSM,
          _buildSummaryCards(),
          if ((_result?.items ?? []).isNotEmpty) ...[
            AppSpacing.gapVerticalMD,
            _buildChartCard(),
          ],
          AppSpacing.gapVerticalMD,
          _buildSearchAndSortBar(items.length),
          AppSpacing.gapVerticalMD,
          if (items.isEmpty)
            _buildEmptyState()
          else
            ...List.generate(items.length, (i) {
              return _buildCategoryCard(items[i], i);
            }),
          AppSpacing.gapVerticalLG,
        ],
      ),
    );
  }

  Widget _buildCompareBanner() {
    final cs = Theme.of(context).colorScheme;
    final isYear = widget.periode == SalesPeriode.year ||
        widget.periode == SalesPeriode.lastYear ||
        widget.year != null;
    final activeYear = widget.year ??
        (widget.periode == SalesPeriode.lastYear
            ? DateTime.now().year - 1
            : DateTime.now().year);
    final periodeLabel = widget.year != null ? 'Tahun ${widget.year}' : widget.periode.label;
    final compareText = isYear
        ? (_compareYear != null ? 'vs Tahun $_compareYear' : 'Tanpa pembanding')
        : (_result?.prevLabel.isNotEmpty == true ? 'vs ${_result!.prevLabel}' : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.category_outlined, size: 16, color: cs.primary),
          AppSpacing.gapHorizontalSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Performa Kategori Online ($periodeLabel)',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                ),
                if (compareText.isNotEmpty)
                  Text(
                    compareText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (isYear) ...[
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 14),
              label: Text(
                '$activeYear',
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: _showSelectYearSheet,
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.compare_arrows, size: 14),
              label: Text(
                _compareYear != null ? '$_compareYear' : 'Pilih',
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: _showCompareYearSheet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final res = _result;
    final totalCategories = res?.totalCategories ?? 0;
    final totalRevenue = res?.totalOmzet ?? 0;
    final totalRevenuePrev = res?.totalOmzetPrev ?? 0;
    final totalQty = res?.totalQty ?? 0;
    final totalQtyPrev = res?.totalQtyPrev ?? 0;

    return Row(
      children: [
        Expanded(
          child: _summaryStatCard(
            label: 'KATEGORI AKTIF',
            valueText: '$totalCategories',
            icon: Icons.grid_view_rounded,
            deltaWidget: Text(
              '${res?.items.length ?? 0} kategori online',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: _summaryStatCard(
            label: 'TOTAL OMZET',
            valueText: FormatUtils.formatCurrencyCompact(totalRevenue),
            icon: Icons.monetization_on_outlined,
            deltaWidget: _buildDeltaBadge(
              totalRevenue,
              totalRevenuePrev,
              isCurrency: true,
            ),
          ),
        ),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: _summaryStatCard(
            label: 'TOTAL QTY',
            valueText: FormatUtils.formatNumber(totalQty),
            icon: Icons.inventory_2_outlined,
            deltaWidget: _buildDeltaBadge(
              totalQty,
              totalQtyPrev,
              isCurrency: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryStatCard({
    required String label,
    required String valueText,
    required IconData icon,
    required Widget deltaWidget,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.secondary),
              AppSpacing.gapHorizontalXS,
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalXS,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          AppSpacing.gapVerticalXS,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: deltaWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final cs = Theme.of(context).colorScheme;
    final items = _result?.items ?? [];
    final activeItems = items.where((it) => it.revenue > 0).toList();
    if (activeItems.isEmpty) return const SizedBox.shrink();

    final totalOmzet = _result?.totalOmzet ?? 1;

    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_outline, size: 16, color: AppColors.secondary),
                  AppSpacing.gapHorizontalXS,
                  Text(
                    'DISTRIBUSI OMZET KATEGORI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Text(
                '${activeItems.length} Kategori',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalMD,
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 55,
                    sections: List.generate(activeItems.length, (i) {
                      final item = activeItems[i];
                      final isTouched = i == _touchedPieIndex;
                      final radius = isTouched ? 45.0 : 38.0;
                      final color = _colorForIndex(i);
                      final pct = totalOmzet > 0 ? (item.revenue / totalOmzet * 100) : 0.0;

                      return PieChartSectionData(
                        value: item.revenue.toDouble(),
                        color: color,
                        title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                        radius: radius,
                        titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: isTouched ? 12 : 10,
                        ),
                      );
                    }),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Omzet',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      FormatUtils.formatCurrencyCompact(totalOmzet),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapVerticalMD,
          // Horizontal / multi-row legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: List.generate(activeItems.length, (i) {
              final item = activeItems[i];
              final color = _colorForIndex(i);
              final pct = totalOmzet > 0 ? (item.revenue / totalOmzet * 100) : 0.0;
              final isTouched = i == _touchedPieIndex;

              return InkWell(
                onTap: () {
                  setState(() {
                    _touchedPieIndex = _touchedPieIndex == i ? -1 : i;
                  });
                },
                borderRadius: AppSpacing.borderRadiusXS,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.categoryName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                          color: isTouched ? cs.primary : cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '(${pct.toStringAsFixed(0)}%)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortBar(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchTextField(
          controller: _searchController,
          hintText: 'Cari kategori atau nama produk...',
          onCleared: () {
            setState(() => _searchQuery = '');
          },
        ),
        AppSpacing.gapVerticalSM,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Menampilkan $count kategori',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Omzet'),
                  selected: _sort == CategorySort.revenue,
                  onSelected: (val) {
                    if (val) setState(() => _sort = CategorySort.revenue);
                  },
                  visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Kuantitas'),
                  selected: _sort == CategorySort.qty,
                  onSelected: (val) {
                    if (val) setState(() => _sort = CategorySort.qty);
                  },
                  visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(SalesCategoryItem item, int index) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _colorForIndex(index);
    final isExpanded = _expandedCategoryIds.contains(item.categoryId);

    // Share calculation relative to total or top category
    final totalMetric = _sort == CategorySort.revenue
        ? (_result?.totalOmzet ?? 1)
        : (_result?.totalQty ?? 1);
    final itemMetric = _sort == CategorySort.revenue ? item.revenue : item.qty;
    final shareRatio = totalMetric > 0 ? (itemMetric / totalMetric).clamp(0.0, 1.0) : 0.0;
    final sharePct = (shareRatio * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isExpanded
              ? AppColors.secondary.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppSpacing.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRankBadge(index + 1),
                    AppSpacing.gapHorizontalSM,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.categoryName,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapVerticalXS,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.secondary.withValues(alpha: 0.15)
                                  : cs.surfaceContainerHighest,
                              borderRadius: AppSpacing.borderRadiusXS,
                            ),
                            child: Text(
                              '${item.productCount} Produk Terjual',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark ? AppColors.secondary : cs.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FormatUtils.formatCurrencyCompact(item.revenue),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _sort == CategorySort.revenue ? AppColors.secondary : null,
                          ),
                        ),
                        Text(
                          '${FormatUtils.formatNumber(item.qty)} pcs',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _sort == CategorySort.qty ? cs.primary : AppColors.onSurfaceVariant,
                            fontWeight: _sort == CategorySort.qty ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                AppSpacing.gapVerticalSM,
                const Divider(height: 1),
                AppSpacing.gapVerticalSM,

                // Two columns: Delta Omzet vs Delta Qty
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YoY Omzet',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildDeltaBadge(
                            item.revenue,
                            item.revenuePrev,
                            isCurrency: true,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YoY Kuantitas',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildDeltaBadge(
                            item.qty,
                            item.qtyPrev,
                            isCurrency: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                AppSpacing.gapVerticalSM,

                // Visual share progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _sort == CategorySort.revenue ? 'Pangsa Omzet' : 'Pangsa Kuantitas',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$sharePct%',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalXS,
                    ClipRRect(
                      borderRadius: AppSpacing.borderRadiusXS,
                      child: LinearProgressIndicator(
                        value: shareRatio,
                        minHeight: 5,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Drilldown top products toggle button & section
          if (item.topProducts.isNotEmpty) ...[
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCategoryIds.remove(item.categoryId);
                  } else {
                    _expandedCategoryIds.add(item.categoryId);
                  }
                });
              },
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                      : cs.surfaceContainerLowest,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_border_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Produk Terlaris (${item.topProducts.length})',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                color: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.15)
                    : cs.surfaceContainerLowest,
                child: Column(
                  children: List.generate(item.topProducts.length, (pIdx) {
                    final prod = item.topProducts[pIdx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${pIdx + 1}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              prod.productName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${FormatUtils.formatNumber(prod.qty)} pcs',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            FormatUtils.formatCurrencyCompact(prod.revenue),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gold, AppColors.inversePrimary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.inversePrimary.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, size: 12, color: Colors.white),
              Text(
                '1',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (rank == 2) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.outlineVariant, AppColors.outline, AppColors.onSurfaceVariant],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '#2',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    if (rank == 3) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.secondaryContainer, AppColors.secondary, AppColors.onSecondaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '#3',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDeltaBadge(int current, int prev, {bool isCurrency = false}) {
    final cs = Theme.of(context).colorScheme;
    final prevText = isCurrency
        ? FormatUtils.formatCurrencyCompact(prev)
        : FormatUtils.formatNumber(prev);

    if (prev == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: AppSpacing.borderRadiusXS,
            ),
            child: Text(
              'Baru',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final delta = current - prev;
    final pct = (delta.abs() / prev * 100).round();
    final isUp = delta > 0;
    final isDown = delta < 0;
    final Color color = isUp
        ? AppColors.success
        : isDown
            ? AppColors.error
            : cs.outline;
    final icon = isUp
        ? Icons.arrow_upward
        : isDown
            ? Icons.arrow_downward
            : Icons.arrow_forward;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '$pct%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapHorizontalXS,
          Text(
            'vs $prevText',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: EmptyState(
        icon: Icons.category_outlined,
        title: _searchQuery.isNotEmpty ? 'Kategori Tidak Ditemukan' : 'Belum Ada Data Kategori',
        subtitle: _searchQuery.isNotEmpty
            ? 'Tidak ada kategori atau produk yang cocok dengan "$_searchQuery"'
            : 'Belum ada data penjualan kategori untuk periode ini',
        action: _searchQuery.isNotEmpty
            ? FilledButton.tonal(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Text('Reset Pencarian'),
              )
            : null,
      ),
    );
  }

  Widget _buildSkeletonView() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: AppSpacing.paddingMD.copyWith(bottom: ModernBottomNav.clearance(context)),
      children: [
        SkeletonLoading(height: 40, borderRadius: AppSpacing.borderRadiusSM),
        AppSpacing.gapVerticalSM,
        Row(
          children: [
            Expanded(child: SkeletonLoading(height: 70, borderRadius: AppSpacing.borderRadiusMD)),
            AppSpacing.gapHorizontalSM,
            Expanded(child: SkeletonLoading(height: 70, borderRadius: AppSpacing.borderRadiusMD)),
            AppSpacing.gapHorizontalSM,
            Expanded(child: SkeletonLoading(height: 70, borderRadius: AppSpacing.borderRadiusMD)),
          ],
        ),
        AppSpacing.gapVerticalMD,
        SkeletonLoading(height: 220, borderRadius: AppSpacing.borderRadiusMD),
        AppSpacing.gapVerticalMD,
        SkeletonLoading(height: 48, borderRadius: AppSpacing.borderRadiusMD),
        AppSpacing.gapVerticalMD,
        ...List.generate(3, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: AppSpacing.borderRadiusMD,
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonAvatar(size: 32),
                    const SizedBox(width: 10),
                    const Expanded(child: SkeletonText(lines: 2, height: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: SkeletonText(lines: 2, height: 10)),
                    const SizedBox(width: 20),
                    const Expanded(child: SkeletonText(lines: 2, height: 10)),
                  ],
                ),
                AppSpacing.gapVerticalSM,
                SkeletonLoading(height: 6, borderRadius: AppSpacing.borderRadiusXS),
              ],
            ),
          );
        }),
      ],
    );
  }
}

