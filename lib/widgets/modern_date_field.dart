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

  const ModernDateField({
    super.key,
    required this.labelText,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.enabled = true,
  });

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime.now(),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: TextEditingController(
        text: value == null ? '' : DateFormat('dd MMM yyyy').format(value!),
      ),
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black),
        ),
        errorText: errorText,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      ),
      readOnly: true,
      enabled: enabled,
      onTap: enabled
          ? () async {
              final date = await showDatePicker(
                context: context,
                initialDate: value ?? firstDate ?? DateTime.now(),
                firstDate: firstDate ?? DateTime.now(),
                lastDate:
                    lastDate ?? DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                onChanged(date);
              }
            }
          : null,
    );
  }
}
