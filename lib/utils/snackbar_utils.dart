import 'package:flutter/material.dart';

import '../widgets/app_snackbar.dart';

export '../widgets/app_snackbar.dart'
    show
        snackBarTextColor,
        buildAppSnackBar,
        showAppSnackBar,
        showSuccessSnackBar,
        showErrorSnackBar,
        showWarningSnackBar,
        showInfoSnackBar;

/// Snackbar dengan teks kontras otomatis terhadap background-nya, floating layout,
/// safe margins, dan icon semantic.
class SnackbarUtils {
  static Color textColorFor(Color background) => snackBarTextColor(background);

  static void show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    showAppSnackBar(
      context,
      message,
      background: backgroundColor,
      duration: duration,
      icon: icon,
    );
  }

  static void success(BuildContext context, String message) {
    showSuccessSnackBar(context, message);
  }

  static void error(BuildContext context, dynamic message) {
    showErrorSnackBar(context, message);
  }

  static void warning(BuildContext context, String message) {
    showWarningSnackBar(context, message);
  }

  static void info(BuildContext context, String message) {
    showInfoSnackBar(context, message);
  }
}
