import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_drawer.dart';
import 'glass_app_bar.dart';
import 'ios_bar_button.dart';
import 'modern_bottom_nav.dart';

/// Scaffold dashboard reusable: AppBar (logo + nama user),
/// Drawer seragam (Beranda/Printer/Bantuan/Logout), body berisi header
/// + daftar [DashboardMenuItem], dan [ModernBottomNav].
///
/// Tujuan: menghilangkan duplikasi ~600 baris AppBar/Drawer/_buildMenuRow
/// yang sebelumnya di-copy ke tiap dashboard. Dark mode adaptif otomatis
/// karena seluruh warna memakai `colorScheme`.
///
/// Ikon menu selalu memakai `colorScheme.primary` (seragam antar dashboard).
class DashboardScaffold extends StatelessWidget {
  final int currentIndex;
  final String title;
  final String? subtitle;
  final List<DashboardMenuItem> menuItems;
  final Widget? bottomAction;
  final Widget? customBody;

  const DashboardScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    this.subtitle,
    this.menuItems = const [],
    this.bottomAction,
    this.customBody,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AppDrawer.loadUserData(),
      builder: (context, snapshot) {
        final userName = snapshot.data?['name'] ?? '';
        final companyName = snapshot.data?['company'] ?? 'SAGANSA';
        final isAdmin = snapshot.data?['isAdmin'] ?? false;
        return _buildScaffold(context, userName, companyName, isAdmin);
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, String userName, String companyName, bool isAdmin) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, userName, companyName),
      drawer: AppDrawer(
        userName: userName,
        companyName: companyName,
        showAppVersion: true,
        extraItems: AppDrawer.buildStandardExtraItems(
          context,
          isAdmin: isAdmin,
        ),
      ),
      body: _buildBody(context),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: currentIndex,
        onTap: (index) {},
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, String userName, String companyName) {
    return GlassAppBar(
      centerTitle: false,
      showBottomBorder: false,
      leading: Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: IosBarButton(
              onTap: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu Navigasi',
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
      title: null,
      actions: const [
        SizedBox(width: AppSpacing.md),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final visibleItems = menuItems.where((m) => m.visible).toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        topPadding + 4,
        AppSpacing.md,
        ModernBottomNav.clearance(context) + AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            AppSpacing.gapVerticalXS,
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (customBody != null)
            customBody!
          else ...[
            ...visibleItems.map((item) => _DashboardMenuCard(item: item)),
            if (bottomAction != null) ...[
              const SizedBox(height: 8),
              bottomAction!,
            ],
          ],
        ],
      ),
    );
  }
}

///
/// Catatan: tidak ada parameter `color` — ikon selalu memakai
/// `colorScheme.primary` agar seragam antar dashboard (sesuai keputusan
/// desain). Warna khusus cukup diberikan via [trailing] jika diperlukan.
class DashboardMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool visible;

  const DashboardMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.visible = true,
  });
}

class _DashboardMenuCard extends StatelessWidget {
  final DashboardMenuItem item;
  const _DashboardMenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: AppSpacing.borderRadiusLG,
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Row(
            children: [
              Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: Icon(item.icon, color: color, size: 28),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.gapVerticalXS,
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.trailing != null) item.trailing!,
              if (item.trailing == null)
                Icon(Icons.chevron_right, color: AppColors.info),
            ],
          ),
        ),
      ),
    );
  }
}
