import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../theme/app_spacing.dart';

/// Baris email yang bisa ditindaklanjuti: tap email = buka aplikasi email
/// (mailto:), tombol copy = salin ke clipboard + snackbar konfirmasi.
class EmailActionRow extends StatelessWidget {
  final String email;

  /// Injection launcher untuk widget test; null = url_launcher.
  final Future<void> Function(Uri url)? launchUrlImpl;

  const EmailActionRow({
    super.key,
    required this.email,
    this.launchUrlImpl,
  });

  Future<void> _openMail(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launch = launchUrlImpl ??
          (Uri u) => url_launcher.launchUrl(
                u,
                mode: url_launcher.LaunchMode.externalApplication,
              );
      await launch(Uri(scheme: 'mailto', path: email));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka aplikasi email: $e')),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: email));
    messenger.showSnackBar(
      const SnackBar(content: Text('Email disalin')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.mail_outline, size: 13, color: cs.onSurfaceVariant),
        AppSpacing.gapHorizontalXS,
        Expanded(
          child: InkWell(
            onTap: () => _openMail(context),
            borderRadius: AppSpacing.borderRadiusSM,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.outlineVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _copy(context),
          icon: Icon(Icons.copy, size: 14, color: cs.onSurfaceVariant),
          tooltip: 'Salin email',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
