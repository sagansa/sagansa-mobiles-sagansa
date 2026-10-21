import 'package:flutter/material.dart';

import '../models/import_model.dart';

/// Dialog penolakan advance/finalisasi: daftar blocker spesifik dari
/// server (nama dokumen/data yang kurang).
///
/// Bila [allowBypass] (semua blocker berupa dokumen), tampil tombol
/// "Lanjut Tanpa Dokumen" dan future resolve `true` saat dipilih.
Future<bool> showImportBlockedDialog(
  BuildContext context, {
  required String title,
  required List<ImportBlocker> blockers,
  bool allowBypass = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lengkapi hal berikut sebelum melanjutkan:'),
          const SizedBox(height: 12),
          for (final blocker in blockers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconFor(blocker.kind), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(blocker.message)),
                ],
              ),
            ),
          if (allowBypass) ...[
            const SizedBox(height: 4),
            Text(
              'Dokumen yang dilewati tetap bisa diunggah nanti sebelum '
              'finalisasi; bypass tercatat di log server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Tutup'),
        ),
        if (allowBypass)
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Lanjut Tanpa Dokumen'),
          ),
      ],
    ),
  );
  return result ?? false;
}

IconData _iconFor(String kind) {
  switch (kind) {
    case 'document':
      return Icons.description_outlined;
    case 'data':
      return Icons.edit_note_outlined;
    default:
      return Icons.info_outline;
  }
}
