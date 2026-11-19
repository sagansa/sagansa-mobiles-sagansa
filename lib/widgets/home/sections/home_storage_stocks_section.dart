import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../pages/storage_stock_list_page.dart';
import '../../../providers/home_dashboard_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../ios_bar_button.dart';

/// Section "Monitoring & Peringatan Stok Gudang (Storage Stock)" di dashboard.
///
/// Dimodelkan mengikuti dashboard Filament sagansa:
/// [ProductStockWidget]: Kartu detail produk dengan status badge (LOW STOCK vs NORMAL),
///    progress bar rasio stok thd. batas minimum (quantity_low), dan tanggal update.
/// Filter Kritis/Semua/Aman di bawah header menggantikan ringkasan KPI angka.
class HomeStorageStocksSection extends StatefulWidget {
  const HomeStorageStocksSection({super.key});

  @override
  State<HomeStorageStocksSection> createState() =>
      _HomeStorageStocksSectionState();
}

enum _StockFilter { lowStock, all, safe }

class _HomeStorageStocksSectionState extends State<HomeStorageStocksSection> {
  _StockFilter _filter = _StockFilter.lowStock;

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _formatNumber(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
    }
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final adminStock =
        context.select<HomeDashboardProvider, HomeAdminStockState>(
            (p) => p.adminStock);
    final homeProvider = context.read<HomeDashboardProvider>();

    final allItems = adminStock.monitoringItems;

    // Filter items
    final lowStockItems = <Map<String, dynamic>>[];
    final safeItems = <Map<String, dynamic>>[];

    for (final item in allItems) {
      final total = _parseDouble(item['calculated_total_stock']);
      final qtyLow = _parseDouble(item['quantity_low']);
      if (total < qtyLow) {
        lowStockItems.add(item);
      } else {
        safeItems.add(item);
      }
    }

    final displayedItems = switch (_filter) {
      _StockFilter.lowStock => lowStockItems,
      _StockFilter.safe => safeItems,
      _StockFilter.all => allItems,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row with Title, Subtitle, and Refresh Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Storage Stock',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (lowStockItems.isNotEmpty) ...[
                        AppSpacing.gapHorizontalSM,
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.12),
                            borderRadius: AppSpacing.borderRadiusFull,
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.error,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${lowStockItems.length} Kritis',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (adminStock.latestStockDate.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Pembaruan terakhir: ${adminStock.latestStockDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                IosBarButton.icon(
                  icon: Icons.refresh_rounded,
                  size: 34,
                  iconSize: 18,
                  tooltip: 'Segarkan Stok',
                  onTap: () => homeProvider.loadAdminStock(),
                ),
                AppSpacing.gapHorizontalXS,
                IosBarButton.icon(
                  icon: Icons.open_in_new_rounded,
                  size: 34,
                  iconSize: 17,
                  tooltip: 'Buka Daftar Stok Gudang',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StorageStockListPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        AppSpacing.gapVerticalMD,

        // Filter Pills Row (pengganti kartu KPI angka)
        _buildFilterRow(
          context,
          lowCount: lowStockItems.length,
          allCount: allItems.length,
          safeCount: safeItems.length,
        ),

        AppSpacing.gapVerticalSM,

        // Loading or List of ProductStock items
        if (adminStock.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (allItems.isEmpty)
          _buildEmptyCard(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Belum Ada Data Monitoring',
            subtitle: 'Data stok gudang belum tersedia di sistem.',
            color: colorScheme.onSurfaceVariant,
          )
        else if (displayedItems.isEmpty && _filter == _StockFilter.lowStock)
          _buildEmptyCard(
            context,
            icon: Icons.check_circle_rounded,
            title: 'Semua Stok Gudang Aman',
            subtitle:
                'Tidak ada produk yang berada di bawah ambang batas minimum.',
            color: AppColors.success,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.88,
            ),
            itemCount: displayedItems.length,
            itemBuilder: (context, index) {
              return _buildProductStockCard(
                context,
                item: displayedItems[index],
                isDark: isDark,
              );
            },
          ),
      ],
    );
  }

  /// Segmented filter selector
  Widget _buildFilterRow(
    BuildContext context, {
    required int lowCount,
    required int allCount,
    required int safeCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            context,
            label: 'Kritis ($lowCount)',
            filter: _StockFilter.lowStock,
            badgeColor: Theme.of(context).colorScheme.error,
          ),
          AppSpacing.gapHorizontalXS,
          _buildFilterChip(
            context,
            label: 'Semua ($allCount)',
            filter: _StockFilter.all,
          ),
          AppSpacing.gapHorizontalXS,
          _buildFilterChip(
            context,
            label: 'Aman ($safeCount)',
            filter: _StockFilter.safe,
            badgeColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required _StockFilter filter,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _filter == filter;

    final selectedBg = isDark
        ? colorScheme.primary.withValues(alpha: 0.25)
        : colorScheme.primary;
    final selectedFg = isDark ? colorScheme.primary : Colors.white;

    final unselectedBg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
        : colorScheme.surface;
    final unselectedFg = colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusFull,
        onTap: () {
          setState(() {
            _filter = filter;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: AppSpacing.borderRadiusFull,
            border: Border.all(
              color: isSelected
                  ? selectedFg.withValues(alpha: 0.3)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3)),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeColor != null && !isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected ? selectedFg : unselectedFg,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Filament ProductStockWidget 3-Grid Card
  Widget _buildProductStockCard(
    BuildContext context, {
    required Map<String, dynamic> item,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = item['name']?.toString() ?? 'Tanpa Nama';
    final calculatedTotal = _parseDouble(item['calculated_total_stock']);
    final qtyLow = _parseDouble(item['quantity_low']);
    final unit = item['unit_nickname']?.toString() ?? '';

    final isLow = calculatedTotal < qtyLow;
    final ratio = qtyLow > 0
        ? (calculatedTotal / qtyLow).clamp(0.0, 1.5)
        : 1.0;
    final progressVal = (ratio / 1.0).clamp(0.0, 1.0);

    final statusColor = isLow ? colorScheme.error : AppColors.success;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showItemDetailSheet(context, item: item, isDark: isDark),
        borderRadius: AppSpacing.borderRadiusMD,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
                : colorScheme.surface,
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: isLow
                  ? colorScheme.error.withValues(alpha: isDark ? 0.4 : 0.25)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : colorScheme.outlineVariant.withValues(alpha: 0.2)),
              width: 0.8,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Row 1: Status indicator dot + tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    isLow ? 'Kritis' : 'Aman',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),

              // Row 2: Product Name
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),

              // Row 3: Current Stock & Unit + Min
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          _formatNumber(calculatedTotal),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: 2),
                        Text(
                          unit,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Min: ${_formatNumber(qtyLow)} $unit'.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 9.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Row 4: Mini Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progressVal,
                  minHeight: 3.5,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : colorScheme.outlineVariant.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetailSheet(
    BuildContext context, {
    required Map<String, dynamic> item,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = item['name']?.toString() ?? 'Tanpa Nama';
    final calculatedTotal = _parseDouble(item['calculated_total_stock']);
    final qtyLow = _parseDouble(item['quantity_low']);
    final unit = item['unit_nickname']?.toString() ?? '';
    final lastStockDate = item['last_stock_date']?.toString();
    final isLow = calculatedTotal < qtyLow;
    final statusColor = isLow ? colorScheme.error : AppColors.success;
    final statusText = isLow ? 'LOW STOCK' : 'NORMAL';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: AppSpacing.borderRadiusFull,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.45) : colorScheme.surface,
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Stok', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                          Text('${_formatNumber(calculatedTotal)} $unit', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: statusColor)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Batas Minimum', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                          Text('${_formatNumber(qtyLow)} $unit', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (lastStockDate != null && lastStockDate.isNotEmpty) ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Update Terakhir', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                            Text(lastStockDate, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          AppSpacing.gapHorizontalMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
