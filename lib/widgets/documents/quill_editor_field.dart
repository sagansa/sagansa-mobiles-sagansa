import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../theme/app_spacing.dart';

/// Field editor isi surat kaya berbasis flutter_quill (task 20).
///
/// Toolbar sengaja dibatasi ke opsi yang didukung penuh alur Mode A:
/// numbered/bullet list, bold/italic, heading H1-H3 (+ Normal), undo/redo.
/// flutter_quill tidak punya dukungan tabel native — tabel tidak dibuat
/// di editor; [tableNote] menampilkan arahan ke Mode B (unggah PDF).
///
/// [controller] dimiliki pemanggil (wizard) agar isi bertahan antar
/// langkah dan konversi Delta↔HTML terjadi di sana.
class QuillEditorField extends StatefulWidget {
  final QuillController controller;

  /// Catatan tentang batasan tabel — null menyembunyikan catatan.
  final Widget? tableNote;

  const QuillEditorField({
    super.key,
    required this.controller,
    this.tableNote,
  });

  @override
  State<QuillEditorField> createState() => _QuillEditorFieldState();
}

class _QuillEditorFieldState extends State<QuillEditorField> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusMD),
            ),
          ),
          child: QuillSimpleToolbar(
            controller: widget.controller,
            config: const QuillSimpleToolbarConfig(
              showDividers: false,
              showFontFamily: false,
              showFontSize: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showListCheck: false,
              headerStyleType: HeaderStyleType.original,
              // Heading dibatasi Normal + H1-H3 (fase editor surat).
              buttonOptions: QuillSimpleToolbarButtonOptions(
                selectHeaderStyleDropdownButton:
                    QuillToolbarSelectHeaderStyleDropdownButtonOptions(
                  attributes: [
                    Attribute.header, // Normal
                    Attribute.h1,
                    Attribute.h2,
                    Attribute.h3,
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 280,
          padding: AppSpacing.paddingSM,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppSpacing.radiusMD),
            ),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: QuillEditor.basic(
            controller: widget.controller,
            focusNode: _focusNode,
            scrollController: _scrollController,
            config: const QuillEditorConfig(
              placeholder: 'Tulis isi surat di sini…',
            ),
          ),
        ),
        if (widget.tableNote != null) ...[
          AppSpacing.gapXS,
          widget.tableNote!,
        ],
      ],
    );
  }
}
