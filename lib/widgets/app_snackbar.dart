import 'package:flutter/material.dart';

import '../utils/error_utils.dart';

export 'app_notification.dart';

/// Warna teks kontras otomatis untuk background snackbar apa pun: putih di
/// atas background gelap/saturated (mis. merah error), gelap di atas
/// background terang (mis. hijau sukses / oranye warning).
Color snackBarTextColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1B1B1B);

/// SnackBar siap pakai dengan kontras warna otomatis, rounded squircle (14pt),
/// floating margin yang aman terhadap bottom navigation bar dan Android navbar,
/// serta icon semantic.
SnackBar buildAppSnackBar(
  String message, {
  required Color background,
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
  IconData? icon,
}) {
  final textColor = snackBarTextColor(background);
  return SnackBar(
    content: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
    backgroundColor: background,
    behavior: SnackBarBehavior.floating,
    elevation: 4,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    dismissDirection: DismissDirection.horizontal,
    duration: duration,
    action: action,
  );
}

/// Tampilkan snackbar dengan kontras warna otomatis dan auto-hide snackbar sebelumnya.
void showAppSnackBar(
  BuildContext context,
  String message, {
  required Color background,
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
  IconData? icon,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    buildAppSnackBar(
      message,
      background: background,
      duration: duration,
      action: action,
      icon: icon,
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message) =>
    showAppSnackBar(
      context,
      message,
      background: const Color(0xFF1E8E3E),
      icon: Icons.check_circle_rounded,
    );

void showErrorSnackBar(BuildContext context, dynamic message) {
  final text = message is String ? message : ErrorUtils.sanitize(message);
  showAppSnackBar(
    context,
    text,
    background: Theme.of(context).colorScheme.error,
    icon: Icons.error_rounded,
  );
}

void showWarningSnackBar(BuildContext context, String message) {
  showAppSnackBar(
    context,
    message,
    background: const Color(0xFFE37400),
    icon: Icons.warning_rounded,
  );
}

void showInfoSnackBar(BuildContext context, String message) {
  showAppSnackBar(
    context,
    message,
    background: const Color(0xFF1F2937),
    icon: Icons.info_rounded,
  );
}
