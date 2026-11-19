import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_spacing.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool showLabel;
  final IconData? lightIcon;
  final IconData? darkIcon;
  final IconData? systemIcon;
  final bool isIosStyle;

  const ThemeToggleButton({
    super.key,
    this.showLabel = false,
    this.lightIcon = Icons.light_mode,
    this.darkIcon = Icons.dark_mode,
    this.systemIcon = Icons.brightness_auto,
    this.isIosStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (!themeProvider.isInitialized) {
          return const SizedBox.shrink();
        }

        final popup = PopupMenuButton<ThemeMode>(
          padding: isIosStyle ? EdgeInsets.zero : const EdgeInsets.all(8),
          icon: Icon(
            _getIconForTheme(themeProvider.themeMode),
            size: isIosStyle ? 20 : null,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Ganti Tema',
          onSelected: (ThemeMode mode) {
            themeProvider.setThemeMode(mode);
          },
          itemBuilder: (BuildContext context) {
            final activeColor = Theme.of(context).colorScheme.primary;
            final inactiveColor = Theme.of(context).iconTheme.color;
            final defaultTextColor =
                Theme.of(context).textTheme.bodyMedium?.color;

            return [
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Row(
                  children: [
                    Icon(
                      lightIcon,
                      color: themeProvider.themeMode == ThemeMode.light
                          ? activeColor
                          : inactiveColor,
                    ),
                    AppSpacing.gapHorizontalSM,
                    Text(
                      'Light',
                      style: TextStyle(
                        color: themeProvider.themeMode == ThemeMode.light
                            ? activeColor
                            : defaultTextColor,
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
                          ? activeColor
                          : inactiveColor,
                    ),
                    AppSpacing.gapHorizontalSM,
                    Text(
                      'Dark',
                      style: TextStyle(
                        color: themeProvider.themeMode == ThemeMode.dark
                            ? activeColor
                            : defaultTextColor,
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
                          ? activeColor
                          : inactiveColor,
                    ),
                    AppSpacing.gapHorizontalSM,
                    Text(
                      'System',
                      style: TextStyle(
                        color: themeProvider.themeMode == ThemeMode.system
                            ? activeColor
                            : defaultTextColor,
                        fontWeight: themeProvider.themeMode == ThemeMode.system
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        );

        if (isIosStyle) {
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Center(child: popup),
          );
        }

        return popup;
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
          // Gunakan WidgetStateProperty karena activeThumbColor,
          // inactiveThumbColor, dan inactiveTrackColor sudah deprecated.
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            return states.contains(WidgetState.selected)
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
            return states.contains(WidgetState.selected)
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.surfaceContainerHighest;
          }),
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
