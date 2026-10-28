import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/document/incoming_models.dart';
import '../../theme/app_spacing.dart';

/// Runutan (thread) surat lintas jenis — timeline vertikal dipakai di
/// detail surat masuk (fase 1b) DAN detail surat keluar (Task 11).
///
/// Node tampil urut kronologis flat (payload backend) dengan indentasi
/// ringan per `depth`. Arah tiap surat terbaca sekali lihat:
/// - **Masuk** (incoming_letter) — chip di KIRI kartu, ikon panah kiri-bawah
///   (`south_west`) — surat datang dari luar ke perusahaan;
/// - **Keluar** (document) — chip di KANAN kartu, ikon panah kanan-atas
///   (`north_east`) — surat dikirim perusahaan ke luar.
///
/// Garis runutan tersambung vertikal di gutter kiri (spine) melewati semua
/// node. Relasi ke surat induk ditulis kecil di atas kartu ("Membalas",
/// "Menindaklanjuti", "Mereferensikan") dengan ikon cabang. Node yang lagi
/// dibuka ([currentNodeType]/[currentNodeId]) disorot: ring ikon + garis
/// tepi kartu primer + tag "Surat ini". Tap kartu (min 48 dp) →
/// [onNodeTap] — NAVIGASI ditangani pemanggil (detail masuk vs keluar
/// membuka halaman berbeda).
///
/// Thread kosong → state berdiri sendiri "Surat berdiri sendiri — belum
/// ada runutan."
class LetterThreadTimeline extends StatelessWidget {
  final ThreadModel thread;

  /// Identitas surat yang sedang dibuka — pasangan type+id (mis.
  /// `incoming_letter` + `il-1`). Null bila konteks tanpa surat aktif.
  final String? currentNodeType;
  final String? currentNodeId;

  /// Dipanggil saat kartu node di-tap. Node saat ini TETAP memanggil
  /// callback (pemanggil bebas mengabaikannya).
  final ValueChanged<ThreadNodeModel>? onNodeTap;

  const LetterThreadTimeline({
    super.key,
    required this.thread,
    this.currentNodeType,
    this.currentNodeId,
    this.onNodeTap,
  });

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy', 'id_ID');

  @override
  Widget build(BuildContext context) {
    if (thread.nodes.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      return Padding(
        padding: AppSpacing.paddingSM,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(Icons.alt_route_rounded,
                size: 44, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Surat berdiri sendiri — belum ada runutan.',
              style: textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Surat ini belum ditautkan sebagai balasan, tindak lanjut, '
              'atau referensi surat lain.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, node) in thread.nodes.indexed)
          _ThreadNodeTile(
            key: ValueKey('thread-node-${node.type}-${node.id}'),
            node: node,
            dateFormat: _dateFormat,
            isCurrent:
                node.type == currentNodeType && node.id == currentNodeId,
            isLast: index == thread.nodes.length - 1,
            onTap: onNodeTap == null ? null : () => onNodeTap!(node),
          ),
      ],
    );
  }
}

class _ThreadNodeTile extends StatelessWidget {
  final ThreadNodeModel node;
  final DateFormat dateFormat;
  final bool isCurrent;
  final bool isLast;
  final VoidCallback? onTap;

  const _ThreadNodeTile({
    super.key,
    required this.node,
    required this.dateFormat,
    required this.isCurrent,
    required this.isLast,
    this.onTap,
  });

  bool get _isIncoming => node.isIncomingLetter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final relation = node.relationLabel;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ——— gutter: ikon arah + garis runutan tersambung ———
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isIncoming
                        ? colorScheme.secondaryContainer
                        : colorScheme.primaryContainer,
                    // Node saat ini disorot ring warna primer.
                    border: isCurrent
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Icon(
                    _isIncoming
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    size: 15,
                    color: _isIncoming
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ——— konten: indentasi ringan per depth + relasi + kartu ———
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: (node.depth.clamp(0, 4)) * 14.0,
                bottom: isLast ? 0 : AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (relation != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          relation,
                          style: textTheme.labelSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  _NodeCard(
                    node: node,
                    isIncoming: _isIncoming,
                    isCurrent: isCurrent,
                    dateFormat: dateFormat,
                    onTap: onTap,
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

class _NodeCard extends StatelessWidget {
  final ThreadNodeModel node;
  final bool isIncoming;
  final bool isCurrent;
  final DateFormat dateFormat;
  final VoidCallback? onTap;

  const _NodeCard({
    required this.node,
    required this.isIncoming,
    required this.isCurrent,
    required this.dateFormat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final date = node.date;
    final partyName = node.partyName;
    final meta = [
      if (date != null) dateFormat.format(date.toLocal()),
      if (partyName != null && partyName.isNotEmpty) partyName,
    ].join(' • ');

    final numberText = Text(
      node.displayNumber,
      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final directionChip = _DirectionChip(isIncoming: isIncoming);

    return Semantics(
      button: onTap != null,
      label: [
        isIncoming ? 'Surat masuk' : 'Surat keluar',
        node.displayNumber,
        if (isCurrent) 'surat ini',
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMD,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: isCurrent
                ? colorScheme.primaryContainer.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerLow,
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: isCurrent
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris 1: chip arah kiri (Masuk) / kanan (Keluar) + nomor +
              // penanda surat ini.
              Row(
                children: [
                  if (isIncoming) ...[
                    directionChip,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(child: numberText),
                  if (isCurrent) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: AppSpacing.borderRadiusFull,
                      ),
                      child: Text(
                        'Surat ini',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (!isIncoming) ...[
                    const SizedBox(width: AppSpacing.sm),
                    directionChip,
                  ],
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (node.title != null && node.title!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  node.title!,
                  style: textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip arah kecil: "Masuk" (ink) / "Keluar" (send) — warna wadah ikon
/// gutter yang sama agar arah terbaca tanpa membaca teks.
class _DirectionChip extends StatelessWidget {
  final bool isIncoming;

  const _DirectionChip({required this.isIncoming});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isIncoming
            ? colorScheme.secondaryContainer
            : colorScheme.primaryContainer,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 12,
            color: isIncoming
                ? colorScheme.onSecondaryContainer
                : colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            isIncoming ? 'Masuk' : 'Keluar',
            style: textTheme.labelSmall?.copyWith(
              color: isIncoming
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
