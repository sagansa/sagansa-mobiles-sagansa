import 'package:flutter/material.dart';

import '../models/import_model.dart';
import '../theme/app_spacing.dart';

/// Dialog penolakan advance/finalisasi: daftar blocker spesifik dari
/// server (nama dokumen/data yang kurang), tiap blocker dalam kartu tint.
///
/// Hierarki aksi: "Tutup" (kembali melengkapi dokumen) adalah aksi utama;
/// bila [allowBypass] (semua blocker berupa dokumen), tombol "Lanjut Tanpa
/// Dokumen" tampil sebagai aksi sekunder bergaya peringatan — bukan tombol
/// utama. Future resolve `true` bila bypass dipilih.
Future<bool> showImportBlockedDialog(
  BuildContext context, {
  required String title,
  required List<ImportBlocker> blockers,
  bool allowBypass = false,
  String? note,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      return AlertDialog(
        title: Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lengkapi hal berikut sebelum melanjutkan:',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            for (final blocker in blockers)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(blocker.kind), size: 18, color: cs.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        blocker.message,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (note != null) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                note,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ] else if (allowBypass) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                'Tetap bisa lanjut tanpa dokumen — dokumen dapat diunggah '
                'kapan saja sebelum finalisasi.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
        // Dua tombol berlabel panjang tidak muat sejajar pada lebar dialog
        // ponsel (Wrap OverflowBar menghasilkan susunan diagonal timpang) —
        // tata menumpuk penuh: aksi sekunder di atas, utama di bawah.
        actions: [
          if (allowBypass)
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      backgroundColor:
                          cs.errorContainer.withValues(alpha: 0.15),
                      side:
                          BorderSide(color: cs.error.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Lanjut Tanpa Dokumen'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tutup'),
            ),
        ],
      );
    },
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
