import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool showLabel;
  final IconData? lightIcon;
  final IconData? darkIcon;
  final IconData? systemIcon;

  const ThemeToggleButton({
    super.key,
    this.showLabel = false,
    this.lightIcon = Icons.light_mode,
    this.darkIcon = Icons.dark_mode,
    this.systemIcon = Icons.brightness_auto,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (!themeProvider.isInitialized) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<ThemeMode>(
          icon: Icon(
            _getIconForTheme(themeProvider.themeMode),
            color: Theme.of(context).iconTheme.color,
          ),
          tooltip: 'Change Theme',
          onSelected: (ThemeMode mode) {
            themeProvider.setThemeMode(mode);
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.light,
              child: Row(
                children: [
                  Icon(
                    lightIcon,
                    color: themeProvider.themeMode == ThemeMode.light
                        ? AppColors.primary
                        : Theme.of(context).iconTheme.color,
                  ),
                  AppSpacing.gapHorizontalSM,
                  Text(
                    'Light',
                    style: TextStyle(
                      color: themeProvider.themeMode == ThemeMode.light
                          ? AppColors.primary
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: themeProvider.themeMode == ThemeMode.light
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.dark,
              child: Row(
                children: [
                  Icon(
                    darkIcon,
                    color: themeProvider.themeMode == ThemeMode.dark
                        ? AppColors.primary
                        : Theme.of(context).iconTheme.color,
                  ),
                  AppSpacing.gapHorizontalSM,
                  Text(
                    'Dark',
                    style: TextStyle(
                      color: themeProvider.themeMode == ThemeMode.dark
                          ? AppColors.primary
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: themeProvider.themeMode == ThemeMode.dark
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.system,
              child: Row(
                children: [
                  Icon(
                    systemIcon,
                    color: themeProvider.themeMode == ThemeMode.system
                        ? AppColors.primary
                        : Theme.of(context).iconTheme.color,
                  ),
                  AppSpacing.gapHorizontalSM,
                  Text(
                    'System',
                    style: TextStyle(
                      color: themeProvider.themeMode == ThemeMode.system
                          ? AppColors.primary
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: themeProvider.themeMode == ThemeMode.system
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconForTheme(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return lightIcon ?? Icons.light_mode;
      case ThemeMode.dark:
        return darkIcon ?? Icons.dark_mode;
      case ThemeMode.system:
        return systemIcon ?? Icons.brightness_auto;
    }
  }
}

/// Simple theme toggle switch
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (!themeProvider.isInitialized) {
          return const SizedBox.shrink();
        }

        return Switch(
          value: themeProvider.themeMode == ThemeMode.dark,
          onChanged: (bool value) {
            themeProvider.setThemeMode(
              value ? ThemeMode.dark : ThemeMode.light,
            );
          },
          activeColor: AppColors.primary,
          inactiveThumbColor: AppColors.onSurfaceVariant,
          inactiveTrackColor: AppColors.surfaceVariant,
        );
      },
    );
  }
}

/// Elegant theme toggle FAB
class ThemeToggleFAB extends StatelessWidget {
  const ThemeToggleFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (!themeProvider.isInitialized) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton(
          mini: true,
          onPressed: () => themeProvider.toggleTheme(),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          tooltip:
              themeProvider.isDarkMode ? 'Switch to Light' : 'Switch to Dark',
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              key: ValueKey(themeProvider.themeMode),
            ),
          ),
        );
      },
    );
  }
}
