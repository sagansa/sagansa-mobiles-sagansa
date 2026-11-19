import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/document/document_models.dart';
import '../../theme/app_spacing.dart';
import '../status_badge.dart';

/// Riwayat penerbitan surat (tab Terbitan di detail): tiap issuance
/// menampilkan tanggal terbit, metode (label ramah), hash SHA-256 pendek
/// 8 karakter (full via salin long-press), note/alasan reissue, dan badge
/// "Berlaku" (aktif) / "Digantikan" (nonaktif).
///
/// Issuance aktif selalu di atas (payload backend sudah terbaru-dulu, tapi
/// aktif diprioritaskan lagi di sini agar mudah ditemukan).
class IssuanceTimeline extends StatelessWidget {
  final List<IssuanceModel> issuances;

  /// Label metode ringkas dipakai sebagai judul baris; versi panjang
  /// [IssuanceModel.methodLabelText] sebagai subtitle.
  const IssuanceTimeline({super.key, required this.issuances});

  static final DateFormat _dateFormat =
      DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  List<IssuanceModel> get _sorted {
    final list = issuances.toList()
      ..sort((a, b) {
        // Aktif selalu di atas; sisanya terbaru dulu (finalizedAt).
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        final at = b.finalizedAt?.compareTo(a.finalizedAt ?? DateTime(0)) ?? 0;
        return at;
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (issuances.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, issuance) in _sorted.indexed)
          _IssuanceTile(
            issuance: issuance,
            isLast: index == _sorted.length - 1,
            dateFormat: _dateFormat,
          ),
      ],
    );
  }
}

class _IssuanceTile extends StatelessWidget {
  final IssuanceModel issuance;
  final bool isLast;
  final DateFormat dateFormat;

  const _IssuanceTile({
    required this.issuance,
    required this.isLast,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hash = issuance.fileSha256;
    final hashShort =
        hash == null || hash.length < 8 ? null : hash.substring(0, 8);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Garis penghubung timeline antar terbitan.
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: issuance.isActive
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issuance.finalizedAt != null
                              ? dateFormat
                                  .format(issuance.finalizedAt!.toLocal())
                              : 'Tanggal terbit tidak diketahui',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      StatusBadge(
                        label: issuance.isActive ? 'Berlaku' : 'Digantikan',
                        type: issuance.isActive
                            ? StatusType.success
                            : StatusType.neutral,
                        style: issuance.isActive
                            ? StatusBadgeStyle.filled
                            : StatusBadgeStyle.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    issuance.methodLabelText,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (issuance.note != null && issuance.note!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Catatan: ${issuance.note}',
                      style: textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (hashShort != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: GestureDetector(
                        onLongPress: hash == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                    ClipboardData(text: hash));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Hash lengkap disalin ke papan klip.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fingerprint_rounded,
                                size: 13, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'SHA-256 $hashShort…',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
