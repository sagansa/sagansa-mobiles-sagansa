import 'package:flutter/material.dart';

class CustomFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? iconColor;

  const CustomFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? Theme.of(context).floatingActionButtonTheme.backgroundColor,
      foregroundColor: iconColor ?? Theme.of(context).floatingActionButtonTheme.foregroundColor,
      tooltip: tooltip,
      child: Icon(
        icon,
      ),
    );
  }
}
