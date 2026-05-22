import 'package:flutter/material.dart';
import '../utils/themes.dart';

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed == null
          ? null
          : () {
              if (!isLoading) {
                onPressed!();
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.goldAccent,
        foregroundColor: AppTheme.primaryDark,
        minimumSize: const Size(double.infinity, 45),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: AppTheme.primaryDark)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon),
                  const SizedBox(width: 8),
                ],
                Text(text),
              ],
            ),
    );
  }
}
