import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../theme/app_spacing.dart';
import '../../widgets/documents/quill_editor_field.dart';

/// Langkah 3 wizard — isi surat via editor kaya (flutter_quill).
///
/// Toolbar: list bernomor/berbutir, bold/italic, heading H1-H3.
/// flutter_quill tidak mendukung tabel — catatan mengarahkan ke Mode B.
class StepEditor extends StatelessWidget {
  final QuillController controller;

  /// Template/draf memuat tabel → isi diratakan jadi teks (peringatan).
  final bool templateUnsupported;

  /// HTML gagal diparse → editor kosong, isi tersimpan tidak diubah.
  final bool templateParseFailed;

  /// Alur salin surat lama — isi tersimpan di server, editor kosong.
  final bool fromDuplicate;

  const StepEditor({
    super.key,
    required this.controller,
    this.templateUnsupported = false,
    this.templateParseFailed = false,
    this.fromDuplicate = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        if (fromDuplicate)
          _note(
            context,
            icon: Icons.content_copy_rounded,
            text: 'Isi disalin dari surat sumber. Editor dimulai kosong — '
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
            text: 'Untuk isi ber tabel kompleks, gunakan unggah PDF (Mode B).',
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
