import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_spacing.dart';

/// Input nominal yang dirancang untuk angka besar (ratusan juta/miliar):
/// rata kanan, angka tabular, ribuan terformat, dan seluruh isi otomatis
/// terpilih saat fokus — mengetik langsung mengganti nilai lama.
///
/// Berbeda dari `ModernTextField`, tidak ada label mengambang di dalam
/// kotak; konteks (nama biaya/estimasi) sudah ada di baris pemanggil.
/// Ruang vertikal lebih lega dan label tidak pernah terpotong.
class AmountField extends StatefulWidget {
  final TextEditingController controller;
  final String? prefixText;
  final String? suffixText;
  final String hintText;
  final String? semanticLabel;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const AmountField({
    super.key,
    required this.controller,
    this.prefixText,
    this.suffixText,
    this.hintText = '0',
    this.semanticLabel,
    this.inputFormatters,
    this.keyboardType = TextInputType.number,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  /// Fokus pertama = seluruh nominal terpilih. Satu ketukan, langsung
  /// menimpa nilai lama tanpa harus menekan backspace berkali-kali.
  void _handleFocus() {
    if (!_focusNode.hasFocus) return;
    final text = widget.controller.text;
    if (text.isEmpty) return;
    widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final accentStyle = theme.textTheme.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    // Garis tepi cream di dark mode jangan sampai terlihat seperti garis
    // putih keras; turunkan opasitasnya.
    final borderColor =
        cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.8);

    return Semantics(
      label: widget.semanticLabel,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textAlign: TextAlign.end,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focusNode.unfocus(),
        onTapOutside: (_) => _focusNode.unfocus(),
        onChanged: widget.onChanged,
        autocorrect: false,
        enableSuggestions: false,
        autofocus: widget.autofocus,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: cs.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: cs.surfaceContainerHighest
              .withValues(alpha: isDark ? 0.45 : 0.35),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          hintText: widget.hintText,
          hintStyle: theme.textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          prefixText: widget.prefixText,
          prefixStyle: accentStyle,
          suffix: widget.suffixText == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(widget.suffixText!, style: accentStyle),
                ),
          border: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMD,
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMD,
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMD,
            borderSide: BorderSide(color: cs.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}
