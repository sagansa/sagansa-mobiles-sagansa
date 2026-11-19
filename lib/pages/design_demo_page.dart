import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_text_field.dart';
import '../widgets/search_text_field.dart';
import '../widgets/section_card.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/status_badge.dart';
import '../widgets/theme_toggle_button.dart';

class DesignDemoPage extends StatefulWidget {
  const DesignDemoPage({super.key});

  @override
  State<DesignDemoPage> createState() => _DesignDemoPageState();
}

class _DesignDemoPageState extends State<DesignDemoPage> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  int _selectedIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Elegant Design Demo'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMD.copyWith(
          top: AppBarInsets.top(context),
          bottom: ModernBottomNav.clearance(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            AppSpacing.gapVerticalXL,
            _buildButtonSection(),
            AppSpacing.gapVerticalXL,
            _buildInputSection(),
            AppSpacing.gapVerticalXL,
            _buildCardSection(),
            AppSpacing.gapVerticalXL,
            _buildLoadingSection(),
            AppSpacing.gapVerticalXL,
            _buildListSection(),
            AppSpacing.gapVerticalXL,
            // Design System Foundation components (WS-DS1 to WS-DS7).
            _buildStatusBadgeSection(),
            AppSpacing.gapVerticalXL,
            _buildEmptyAndErrorStateSection(),
            AppSpacing.gapVerticalXL,
            _buildDetailRowSection(),
            AppSpacing.gapVerticalXL,
            _buildSectionCardDemo(),
            AppSpacing.gapVerticalXL,
            _buildFilterChipRowSection(),
            AppSpacing.gapVerticalXL,
            _buildSearchTextFieldSection(),
          ],
        ),
      ),
      floatingActionButton: const ThemeToggleFAB(),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Black & White Design',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.gapVerticalSM,
        Text(
          'A sophisticated design system with clean aesthetics and smooth animations.',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildButtonSection() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Buttons',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapVerticalMD,
        ModernButton(
          text: 'Primary Button',
          onPressed: () => _showSnackBar('Primary button pressed'),
          icon: Icons.touch_app,
        ),
        AppSpacing.gapVerticalSM,
        ModernButton(
          text: 'Secondary Button',
          onPressed: () => _showSnackBar('Secondary button pressed'),
          icon: Icons.favorite_border,
        ),
        AppSpacing.gapVerticalSM,
        ModernButton(
          text: 'Action Button',
          onPressed: () => _showSnackBar('Action button pressed'),
          icon: Icons.text_fields,
        ),
        AppSpacing.gapVerticalSM,
        ModernButton(
          text: _isLoading ? 'Loading...' : 'Loading Button',
          isLoading: _isLoading,
          onPressed: () => _toggleLoading(),
          icon: Icons.refresh,
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Input Fields',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapVerticalMD,
        ModernTextField(
          labelText: 'Email Address',
          controller: _textController,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        AppSpacing.gapVerticalMD,
        ModernTextField(
          labelText: 'Password',
          controller: TextEditingController(),
          prefixIcon: Icons.lock_outlined,
          obscureText: true,
          suffixIcon: const Icon(Icons.visibility_outlined),
        ),
        AppSpacing.gapVerticalMD,
        ModernTextField(
          labelText: 'Message',
          controller: TextEditingController(),
          prefixIcon: Icons.message_outlined,
        ),
      ],
    );
  }

  Widget _buildCardSection() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Cards',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapVerticalMD,
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusLG,
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: AppSpacing.paddingLG,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: AppSpacing.borderRadiusSM,
                      ),
                      child: Icon(
                        Icons.design_services,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    AppSpacing.gapHorizontalMD,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Design System',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Modern UI components',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapVerticalMD,
                Text(
                  'This elegant design system provides a consistent and beautiful user experience with smooth animations and clean aesthetics.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSection() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skeleton Loading States',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapVerticalMD,
        const SkeletonCard(height: 120),
        AppSpacing.gapVerticalSM,
        const SkeletonListItem(hasAvatar: true, hasTrailing: true),
        AppSpacing.gapVerticalSM,
        const SkeletonText(lines: 3),
      ],
    );
  }

  Widget _buildListSection() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant List Items',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapVerticalMD,
        ...List.generate(3, (index) {
          final items = [
            {
              'icon': Icons.palette,
              'title': 'Color Palette',
              'subtitle': 'Black & white elegance'
            },
            {
              'icon': Icons.text_fields,
              'title': 'Typography',
              'subtitle': 'Clean and readable fonts'
            },
            {
              'icon': Icons.animation,
              'title': 'Animations',
              'subtitle': 'Smooth transitions'
            },
          ];
          final item = items[index];

          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: AppColors.info,
                ),
              ),
              title: Text(
                item['title'] as String,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                item['subtitle'] as String,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.info,
              ),
              onTap: () => _showSnackBar('${item['title']} tapped'),
            ),
          );
        }),
      ],
    );
  }

  void _showSnackBar(String message) {
    showAppSnackBar(
      context,
      message,
      background: Theme.of(context).colorScheme.primary,
    );
  }

  void _toggleLoading() {
    setState(() => _isLoading = !_isLoading);
    if (_isLoading) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  // ===========================================================================
  // Design System Foundation Sections (WS-DS1 to WS-DS7)
  // ===========================================================================

  Widget _buildStatusBadgeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('StatusBadge',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const StatusBadge(label: 'Success', type: StatusType.success),
            const StatusBadge(label: 'Warning', type: StatusType.warning),
            const StatusBadge(label: 'Error', type: StatusType.error),
            const StatusBadge(label: 'Info', type: StatusType.info),
            const StatusBadge(label: 'Neutral', type: StatusType.neutral),
            const StatusBadge(label: 'Outline Success',
                type: StatusType.success, style: StatusBadgeStyle.outline),
            const StatusBadge(label: 'Outline Error',
                type: StatusType.error, style: StatusBadgeStyle.outline),
            const StatusBadge(label: 'Medium Success',
                type: StatusType.success, size: BadgeSize.medium),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyAndErrorStateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EmptyState & ErrorState',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        SizedBox(
          height: 250,
          child: Row(
            children: [
              Expanded(
                child: EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Tidak ada data',
                  subtitle: 'Coba tarik ke bawah',
                ),
              ),
              Expanded(
                child: ErrorState(
                  message: 'Gagal memuat',
                  onRetry: () {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DetailRow & IconDetailRow',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        SectionCard(
          child: Column(
            children: [
              DetailRow(label: 'Store', value: 'Toko A', valueBold: true),
              DetailRow(label: 'Date', value: '2026-07-22'),
              DetailRow(label: 'Amount', value: 'Rp 150.000'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCardDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SectionCard',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        SectionCard(
          title: 'Transaction Details',
          icon: Icons.receipt_long,
          actions: [
            BarButtonCluster(
              actions: [
                BarButtonSpec(
                  icon: Icons.edit,
                  iconSize: 18,
                  tooltip: 'Ubah',
                  onTap: () {},
                ),
              ],
            ),
          ],
          child: const Text('Card body content goes here.'),
        ),
      ],
    );
  }

  Widget _buildFilterChipRowSection() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        String selected = 'Semua';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FilterChipRow',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.gapVerticalSM,
            FilterChipRow<String>(
              options: const ['Semua', 'Pending', 'Lunas', 'Transfer'],
              selected: selected,
              onSelected: (val) => setLocalState(() => selected = val ?? 'Semua'),
              getLabel: (s) => s,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchTextFieldSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SearchTextField',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        SearchTextField(
          controller: _textController,
          hintText: 'Cari nomor resi / nama...',
          suffixWidget: IconButton(
            tooltip: 'Pindai QR',
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner, size: 20),
          ),
        ),
      ],
    );
  }
}
