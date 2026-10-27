import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/document/document_models.dart';
import '../../theme/app_spacing.dart';

/// Lampiran yang sudah dipilih tapi belum diunggah — label & urutan
/// diatur di sini; `sort` final dikirim saat unggah.
class PendingAttachment {
  final File file;
  final TextEditingController labelController;

  PendingAttachment({required this.file, required String initialLabel})
      : labelController = TextEditingController(text: initialLabel);

  String get fileName => file.path.split(Platform.pathSeparator).last;
}

/// Langkah 4 wizard — lampiran: pilih banyak file (pdf/jpg/jpeg/png/xlsx),
/// beri label, atur urutan, unggah per file; lampiran terunggah bisa dihapus.
class StepAttachments extends StatelessWidget {
  final List<PendingAttachment> pending;
  final bool picking;
  final VoidCallback onPickFiles;
  final void Function(int index) onRemovePending;
  final void Function(int index, int delta) onMovePending;
  final Future<void> Function(int index) onUploadPending;

  final List<AttachmentModel> uploaded;
  final Set<String> uploadingIds;
  final void Function(AttachmentModel attachment) onDeleteUploaded;

  const StepAttachments({
    super.key,
    required this.pending,
    required this.picking,
    required this.onPickFiles,
    required this.onRemovePending,
    required this.onMovePending,
    required this.onUploadPending,
    required this.uploaded,
    required this.uploadingIds,
    required this.onDeleteUploaded,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        FilledButton.tonalIcon(
          onPressed: picking ? null : onPickFiles,
          icon: picking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file_rounded),
          label: const Text('Pilih file (PDF/JPG/PNG/XLSX)'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Maks 20 MB per file. Beri label & urutkan sebelum unggah.',
          style: textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        if (pending.isNotEmpty) ...[
          Text('Siap diunggah',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < pending.length; i++)
            _PendingRow(
              item: pending[i],
              index: i,
              count: pending.length,
              onRemove: () => onRemovePending(i),
              onMove: (delta) => onMovePending(i, delta),
              onUpload: () => onUploadPending(i),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('Terunggah (${uploaded.length})',
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        if (uploaded.isEmpty)
          Text(
            'Belum ada lampiran terunggah.',
            style: textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          )
        else
          for (final attachment in uploaded)
            _UploadedRow(
              attachment: attachment,
              deleting: uploadingIds.contains(attachment.id),
              onDelete: () => onDeleteUploaded(attachment),
            ),
      ],
    );
  }
}

class _PendingRow extends StatelessWidget {
  final PendingAttachment item;
  final int index;
  final int count;
  final VoidCallback onRemove;
  final ValueChanged<int> onMove;
  final VoidCallback onUpload;

  const _PendingRow({
    required this.item,
    required this.index,
    required this.count,
    required this.onRemove,
    required this.onMove,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: AppSpacing.paddingSM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Naikkan urutan',
                  onPressed: index == 0 ? null : () => onMove(-1),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Turunkan urutan',
                  onPressed: index == count - 1 ? null : () => onMove(1),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Buang file',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.labelController,
                    decoration: const InputDecoration(
                      labelText: 'Label lampiran',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: onUpload,
                  child: const Text('Unggah'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadedRow extends StatelessWidget {
  final AttachmentModel attachment;
  final bool deleting;
  final VoidCallback onDelete;

  const _UploadedRow({
    required this.attachment,
    required this.deleting,
    required this.onDelete,
  });

  String? get _sizeLabel {
    final size = attachment.size;
    if (size == null) return null;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: AppSpacing.paddingSM,
        leading: const Icon(Icons.task_rounded),
        title: Text(attachment.label,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          'urutan ${attachment.sort + 1}',
          if (_sizeLabel != null) _sizeLabel!,
        ].join(' • ')),
        trailing: deleting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Hapus lampiran',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
      ),
    );
  }
}
