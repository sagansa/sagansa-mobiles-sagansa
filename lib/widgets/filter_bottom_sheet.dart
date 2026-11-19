import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'modern_picker_sheet.dart';

/// Field spec untuk FilterBottomSheet.
abstract class FilterField<T> {
  final String label;
  final T value;
  const FilterField({required this.label, required this.value});
}

/// Dropdown field (karyawan, status, dll — nilai dari API).
class DropdownFilterField<T> extends FilterField<T?> {
  final List<(T, String)> options;

  /// Label field lain yang memengaruhi opsi dropdown ini (mis. pilihan
  /// "Status Karyawan" menyaring daftar opsi "Karyawan").
  final String? dependsOn;

  /// Menyaring [options] berdasarkan nilai field [dependsOn] saat ini.
  final List<(T, String)> Function(
      List<(T, String)> options, dynamic dependencyValue)? optionFilter;

  const DropdownFilterField({
    required super.label,
    required super.value,
    required this.options,
    this.dependsOn,
    this.optionFilter,
  })  : assert(dependsOn == null || optionFilter != null,
            'optionFilter wajib bila dependsOn diisi'),
        super();

  /// Opsi efektif untuk [dependencyValue] saat ini (opsi penuh bila tidak
  /// ada dependency).
  ///
  /// [optionFilter] tidak boleh dibaca langsung dari luar lewat referensi
  /// bertipe mentah (`DropdownFilterField` tanpa type argument, seperti di
  /// [_FilterBottomSheetState._buildField]): getter generik yang menaruh T
  /// di posisi kontravarian (parameter fungsi) menjalani cek runtime, dan
  /// `List<(int, String)> Function(...)` bukan subtype dari
  /// `List<(dynamic, String)> Function(...)` — TypeError saat build sheet.
  /// Di dalam metode ini akses member bertipe persis, jadi aman.
  List<(dynamic, String)> resolveOptions(dynamic dependencyValue) {
    final filter = optionFilter;
    if (dependsOn == null || filter == null) return options;
    return filter(options, dependencyValue);
  }
}

/// Date-range field.
class DateRangeFilterField extends FilterField<(DateTime, DateTime)?> {
  const DateRangeFilterField({required super.label, required super.value})
      : super();
}

/// Chip field untuk filter cepat inline (≤1 filter).
class ChipFilterField<T> extends FilterField<T?> {
  final List<(T, String)> options;
  const ChipFilterField({
    required super.label,
    required super.value,
    required this.options,
  });
}

/// Field teks bebas (pencarian nama/email/dll).
class TextFilterField extends FilterField<String?> {
  final String? hint;
  const TextFilterField({
    required super.label,
    required super.value,
    this.hint,
  });
}

/// Bottom sheet generik untuk filter.
/// Panggil: FilterBottomSheet.show(context, fields: [...], onApply: (...) {})
class FilterBottomSheet extends StatefulWidget {
  final List<FilterField> fields;
  final void Function(Map<String, dynamic>) onApply;
  final String title;
  final VoidCallback? onReset;

  const FilterBottomSheet({
    super.key,
    required this.fields,
    required this.onApply,
    this.title = 'Filter',
    this.onReset,
  });

  static Future<void> show(
    BuildContext context, {
    required List<FilterField> fields,
    required void Function(Map<String, dynamic>) onApply,
    String title = 'Filter',
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterBottomSheet(
        fields: fields,
        onApply: onApply,
        title: title,
        onReset: onReset,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Map<String, dynamic> _values;

  @override
  void initState() {
    super.initState();
    _values = {for (var f in widget.fields) f.label: f.value};
  }

  void _updateValue(String label, dynamic value) {
    setState(() {
      _values[label] = value;
      // Reset field yang bergantung pada field ini agar pilihan tidak
      // kontradiktif (mis. ganti Status Karyawan → reset pilihan Karyawan).
      for (final f in widget.fields) {
        if (f is DropdownFilterField && f.dependsOn == label) {
          _values[f.label] = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: cs.surface.withValues(alpha: 0.85),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: AppSpacing.borderRadiusXS,
            ),
          ),
          Padding(
            padding: AppSpacing.paddingMD,
            child: Row(
              children: [
                // Judul dalam Expanded + ellipsis: judul panjang / skala
                // teks besar tidak membuat baris header meluap.
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.onReset != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(onPressed: widget.onReset, child: const Text('Reset')),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: AppSpacing.paddingMD,
              itemCount: widget.fields.length,
              separatorBuilder: (_, __) => AppSpacing.gapVerticalLG,
              itemBuilder: (_, i) {
                final field = widget.fields[i];
                return _buildField(field);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Row(
                children: [
                  if (widget.onReset != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onReset,
                        child: const Text('Reset'),
                      ),
                    ),
                  if (widget.onReset != null) AppSpacing.gapHorizontalMD,
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onApply(_values);
                      },
                      child: const Text('Terapkan'),
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
  ),
);
  }

  Widget _buildField(FilterField field) {
    if (field is DropdownFilterField) {
      final options = field.resolveOptions(
          field.dependsOn == null ? null : _values[field.dependsOn]);
      return _DropdownFieldWidget(
        label: field.label,
        value: _values[field.label],
        options: options,
        onChanged: (v) => _updateValue(field.label, v),
      );
    }
    if (field is DateRangeFilterField) {
      return _DateRangeFieldWidget(
        label: field.label,
        value: _values[field.label],
        onChanged: (v) => _updateValue(field.label, v),
      );
    }
    if (field is ChipFilterField) {
      return _ChipFieldWidget(
        label: field.label,
        value: _values[field.label],
        options: field.options,
        onChanged: (v) => _updateValue(field.label, v),
      );
    }
    if (field is TextFilterField) {
      return _TextFieldWidget(
        label: field.label,
        initialvalue: field.value,
        hint: field.hint,
        onChanged: (v) => _updateValue(field.label, v),
      );
    }
    return const SizedBox.shrink();
  }
}

class _DropdownFieldWidget<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;

  const _DropdownFieldWidget({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        AppSpacing.gapVerticalXS,
        InkWell(
          onTap: () => _showDropdown(context),
          borderRadius: AppSpacing.borderRadiusMD,
          child: Container(
            padding: AppSpacing.paddingSM.copyWith(right: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: AppSpacing.borderRadiusMD,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null ? _labelFor(value) : 'Pilih $label',
                    style: tt.bodyMedium?.copyWith(
                      color: value != null ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Returns the display label for [v] from [options], or a fallback string
  /// when [v] is not present (e.g. the selected id is no longer in the list).
  ///
  /// A plain loop is used instead of `firstWhere(orElse:)` on purpose: the
  /// sheet is generic on `T` but built with `T = dynamic` (see `_buildField`),
  /// so an `orElse` fallback closure would be checked against the *runtime*
  /// element type of `options` (e.g. `(int, String)`) and crash with a
  /// `(dynamic, String) is not a subtype of (int, String)` TypeError when
  /// `value` isn't found.
  ///
  /// The parameter is `T?` (not `T`) because `T` may itself be nullable (e.g.
  /// `DropdownFilterField<int?>`), so a `value != null` check cannot promote
  /// `T?` to `T` for a type parameter.
  String _labelFor(T? v) {
    for (final opt in options) {
      if (opt.$1 == v) return opt.$2;
    }
    return '$v';
  }

  void _showDropdown(BuildContext context) {
    ModernPickerSheet.showFromTuples<T?>(
      context: context,
      title: label,
      options: options.map((opt) => (opt.$1 as T?, opt.$2)).toList(),
      selectedItem: value,
      showAllOption: true,
      allOptionLabel: 'Semua $label',
      allOptionValue: null,
      onSelected: (val) => onChanged(val),
    );
  }
}

class _DateRangeFieldWidget extends StatelessWidget {
  final String label;
  final (DateTime, DateTime)? value;
  final ValueChanged<(DateTime, DateTime)?> onChanged;

  const _DateRangeFieldWidget({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        AppSpacing.gapVerticalXS,
        InkWell(
          onTap: () => _pickDateRange(context),
          borderRadius: AppSpacing.borderRadiusMD,
          child: Container(
            padding: AppSpacing.paddingSM.copyWith(right: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: AppSpacing.borderRadiusMD,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range, color: AppColors.info, size: 20),
                AppSpacing.gapHorizontalSM,
                Expanded(
                  child: Text(
                    value != null
                        ? '${fmt.format(value!.$1)} - ${fmt.format(value!.$2)}'
                        : 'Pilih $label',
                    style: tt.bodyMedium?.copyWith(
                      color: value != null ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (value != null)
                  IconButton(
                    icon: Icon(Icons.clear, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => onChanged(null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: value != null
          ? DateTimeRange(start: value!.$1, end: value!.$2)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme),
        child: child!,
      ),
    );
    if (picked != null) onChanged((picked.start, picked.end));
  }
}

class _ChipFieldWidget<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;

  const _ChipFieldWidget({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        AppSpacing.gapVerticalXS,
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text('Semua'),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
            ...options.map((opt) => ChoiceChip(
                  label: Text(opt.$2),
                  selected: value == opt.$1,
                  onSelected: (_) => onChanged(opt.$1),
                )),
          ],
        ),
      ],
    );
  }
}

class _TextFieldWidget extends StatefulWidget {
  final String label;
  final String? initialvalue;
  final String? hint;
  final ValueChanged<String?> onChanged;

  const _TextFieldWidget({
    required this.label,
    required this.initialvalue,
    required this.onChanged,
    this.hint,
  });

  @override
  State<_TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<_TextFieldWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialvalue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        AppSpacing.gapVerticalXS,
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: (v) => widget.onChanged(v.trim().isEmpty ? null : v.trim()),
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Cari...',
            prefixIcon: Icon(Icons.search, color: AppColors.info),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMD,
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMD,
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}