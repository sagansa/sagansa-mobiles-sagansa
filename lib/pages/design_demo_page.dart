import 'package:flutter/material.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_text_field.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/theme_toggle_button.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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
      appBar: AppBar(
        title: const Text('Elegant Design Demo'),
        actions: [
          const ThemeToggleButton(),
          AppSpacing.gapHorizontalSM,
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(),
            AppSpacing.gapVerticalXL,

            // Button Section
            _buildButtonSection(),
            AppSpacing.gapVerticalXL,

            // Input Section
            _buildInputSection(),
            AppSpacing.gapVerticalXL,

            // Card Section
            _buildCardSection(),
            AppSpacing.gapVerticalXL,

            // Loading Section
            _buildLoadingSection(),
            AppSpacing.gapVerticalXL,

            // List Section
            _buildListSection(),
          ],
        ),
      ),
      floatingActionButton: const ThemeToggleFAB(),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          ModernBottomNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
          ),
          ModernBottomNavItem(
            icon: Icons.design_services_outlined,
            activeIcon: Icons.design_services,
            label: 'Design',
          ),
          ModernBottomNavItem(
            icon: Icons.palette_outlined,
            activeIcon: Icons.palette,
            label: 'Theme',
          ),
          ModernBottomNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Black & White Design',
          style: AppTypography.headlineMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.gapVerticalSM,
        Text(
          'A sophisticated design system with clean aesthetics and smooth animations.',
          style: AppTypography.bodyLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildButtonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Buttons',
          style: AppTypography.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
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
          text: 'Outlined Button',
          type: ModernButtonType.outlined,
          onPressed: () => _showSnackBar('Outlined button pressed'),
          icon: Icons.favorite_border,
        ),
        AppSpacing.gapVerticalSM,
        ModernButton(
          text: 'Text Button',
          type: ModernButtonType.text,
          onPressed: () => _showSnackBar('Text button pressed'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Input Fields',
          style: AppTypography.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapVerticalMD,
        ModernTextField(
          labelText: 'Email Address',
          controller: _textController,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          hintText: 'Enter your email',
        ),
        AppSpacing.gapVerticalMD,
        ModernTextField(
          labelText: 'Password',
          controller: TextEditingController(),
          prefixIcon: Icons.lock_outlined,
          obscureText: true,
          hintText: 'Enter your password',
          suffixIcon: const Icon(Icons.visibility_outlined),
        ),
        AppSpacing.gapVerticalMD,
        ModernTextField(
          labelText: 'Message',
          controller: TextEditingController(),
          prefixIcon: Icons.message_outlined,
          maxLines: 3,
          hintText: 'Enter your message here...',
        ),
      ],
    );
  }

  Widget _buildCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant Cards',
          style: AppTypography.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapVerticalMD,
        Card(
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
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: AppSpacing.borderRadiusSM,
                      ),
                      child: Icon(
                        Icons.design_services,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    AppSpacing.gapHorizontalMD,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Design System',
                            style: AppTypography.titleMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Modern UI components',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skeleton Loading States',
          style: AppTypography.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegant List Items',
          style: AppTypography.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
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
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                item['title'] as String,
                style: AppTypography.titleSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                item['subtitle'] as String,
                style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () => _showSnackBar('${item['title']} tapped'),
            ),
          );
        }),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusSM,
        ),
      ),
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
}
