import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pages/sales_dashboard_page.dart';
import '../../../providers/home_dashboard_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/format_utils.dart';
import '../home_compact_card.dart';

/// Admin card #2: Omzet Kemarin.
/// Baca sales.yesterdayOmzet dari provider.
class HomeYesterdayOmzetCard extends StatelessWidget {
  const HomeYesterdayOmzetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sales = context.select<HomeDashboardProvider, HomeSalesState>(
        (p) => p.sales);

    final displayValue = sales.yesterdayOmzet == null
        ? '-'
        : FormatUtils.formatCurrencyCompact(sales.yesterdayOmzet!);

    final todayValue = sales.todayOmzet != null
        ? 'Hari ini: ${FormatUtils.formatCurrencyCompact(sales.todayOmzet!)}'
        : null;

    return HomeCompactCard(
      icon: Icons.bar_chart,
      iconColor: AppColors.primary,
      value: displayValue,
      subValue: todayValue,
      label: 'Omzet Kemarin',
      isLoading: sales.isLoading,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SalesDashboardPage()),
      ),
    );
  }
}
