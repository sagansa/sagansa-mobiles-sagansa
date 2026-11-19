import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../theme/app_spacing.dart';
import '../../widgets/documents/quill_editor_field.dart';

/// Langkah 3 wizard — isi surat via editor kaya (flutter_quill).
///
/// Toolbar: list bernomor/berbutir, bold/italic, heading H1-H3.
/// flutter_quill tidak mendukung tabel — catatan mengarahkan ke Mode B.
///
/// Menulis isi surat jarang selesai sekali duduk, jadi langkah ini punya
/// penyimpanan eksplisit: tombol "Simpan isi" + status tersimpan yang
/// selalu terlihat di atas editor. Wizard juga menyimpan otomatis saat
/// pengguna berhenti mengetik, tetapi tombol manual tetap disediakan agar
/// pengguna yakin isinya sudah aman sebelum menutup aplikasi.
class StepEditor extends StatelessWidget {
  final QuillController controller;

  /// Template/draf memuat tabel → isi diratakan jadi teks (peringatan).
  final bool templateUnsupported;

  /// HTML gagal diparse → editor kosong, isi tersimpan tidak diubah.
  final bool templateParseFailed;

  /// Alur salin surat lama — isi tersimpan di server, editor kosong.
  final bool fromDuplicate;

  /// Simpan isi sekarang (null = draf belum ada / penyimpanan tak tersedia).
  final VoidCallback? onSave;

  /// Penyimpanan sedang berjalan — tombol dinonaktifkan + spinner.
  final bool saving;

  /// Ada perubahan yang belum tersimpan di server.
  final bool dirty;

  /// Waktu simpan terakhir yang berhasil (null = belum pernah).
  final DateTime? lastSavedAt;

  const StepEditor({
    super.key,
    required this.controller,
    this.templateUnsupported = false,
    this.templateParseFailed = false,
    this.fromDuplicate = false,
    this.onSave,
    this.saving = false,
    this.dirty = false,
    this.lastSavedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SaveBar(
          onSave: onSave,
          saving: saving,
          dirty: dirty,
          lastSavedAt: lastSavedAt,
        ),
        Expanded(
          child: ListView(
            padding: AppSpacing.paddingMD,
            children: [
              if (fromDuplicate)
                _note(
                  context,
                  icon: Icons.content_copy_rounded,
                  text:
                      'Isi disalin dari surat sumber. Editor dimulai kosong — '
                      'biarkan kosong untuk memakai isi salinan apa adanya, atau '
                      'tulis ulang untuk menggantinya.',
                ),
              if (templateUnsupported)
                _note(
                  context,
                  icon: Icons.table_chart_outlined,
                  text: 'Isi awal memuat tabel yang tidak didukung editor — '
                      'tampilannya diratakan menjadi teks. Periksa hasil di '
                      'langkah pratinjau.',
                ),
              if (templateParseFailed)
                _note(
                  context,
                  icon: Icons.warning_amber_rounded,
                  text: 'Format isi sebelumnya tidak dapat dimuat ke editor. '
                      'Editor dimulai kosong; isi yang tersimpan tidak berubah '
                      'sampai Anda menyimpan langkah ini.',
                ),
              QuillEditorField(
                controller: controller,
                tableNote: _note(
                  context,
                  icon: Icons.info_outline_rounded,
                  text:
                      'Untuk isi ber tabel kompleks, gunakan unggah PDF (Mode B).',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _note(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingSM,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar status + aksi simpan yang selalu terlihat di atas editor.
class _SaveBar extends StatelessWidget {
  final VoidCallback? onSave;
  final bool saving;
  final bool dirty;
  final DateTime? lastSavedAt;

  const _SaveBar({
    required this.onSave,
    required this.saving,
    required this.dirty,
    required this.lastSavedAt,
  });

  String get _statusText {
    if (saving) return 'Menyimpan isi surat…';
    if (dirty) {
      return 'Ada perubahan yang belum tersimpan. Isi juga disimpan otomatis '
          'saat Anda pindah langkah.';
    }
    final savedAt = lastSavedAt;
    if (savedAt == null) {
      return 'Belum ada perubahan. Tekan Simpan isi kapan saja agar tulisan '
          'Anda aman.';
    }
    return 'Tersimpan ${_formatTime(savedAt)}. Anda bisa lanjut menulis '
        'kapan saja.';
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour.$minute';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active = onSave != null && !saving;

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingHorizontalMD.copyWith(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: dirty
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: dirty
                ? colorScheme.primary.withValues(alpha: 0.25)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            saving
                ? Icons.cloud_sync_outlined
                : dirty
                    ? Icons.edit_note_rounded
                    : Icons.cloud_done_outlined,
            size: 22,
            color: dirty ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: dirty
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: dirty ? FontWeight.w500 : FontWeight.normal,
                height: 1.35,
              ),
            ),
          ),
          // Tombol hanya saat ada perubahan — status "Tersimpan" cukup
          // lewat teks, tanpa pill duplikat dgn tombol.
          if (dirty) ...[
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: active ? onSave : null,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('Simpan'),
            ),
          ],
        ],
      ),
    );
  }
}
