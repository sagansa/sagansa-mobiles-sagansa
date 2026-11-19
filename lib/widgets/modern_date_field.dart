import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ModernDateField extends StatelessWidget {
  final String labelText;
  final DateTime? value;
  final Function(DateTime?) onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;
  final bool enabled;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;
  final bool isRequired;
  final String? Function(DateTime?)? validator;

  const ModernDateField({
    super.key,
    required this.labelText,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.enabled = true,
    this.isDense = true,
    this.contentPadding,
    this.isRequired = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = isRequired ? '$labelText *' : labelText;
    return FormField<DateTime>(
      initialValue: value,
      validator: validator,
      builder: (state) {
        final hasError = state.hasError || errorText != null;
        final errorMsg = errorText ?? state.errorText;

        return TextFormField(
          key: ValueKey(value),
          initialValue: value == null ? '' : DateFormat('dd/MM/yyyy').format(value!),
          decoration: InputDecoration(
            isDense: isDense,
            contentPadding: contentPadding ??
                (isDense
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 11)
                    : null),
            labelText: effectiveLabel,
            prefixIcon: const Icon(Icons.calendar_today, size: 20),
            errorText: hasError ? errorMsg : null,
          ),
          readOnly: true,
          enabled: enabled,
      onTap: enabled
          ? () async {
              final effectiveFirstDate = firstDate ?? DateTime.now();
              final effectiveLastDate =
                  lastDate ?? DateTime.now().add(const Duration(days: 365));
              final initial = value ?? DateTime.now();
              final clamped = initial.isBefore(effectiveFirstDate)
                  ? effectiveFirstDate
                  : initial.isAfter(effectiveLastDate)
                      ? effectiveLastDate
                      : initial;
              final date = await showDatePicker(
                context: context,
                initialDate: clamped,
                firstDate: effectiveFirstDate,
                lastDate: effectiveLastDate,
              );
              if (date != null) {
                state.didChange(date);
                onChanged(date);
              }
            }
          : null,
        );
      },
    );
  }
}