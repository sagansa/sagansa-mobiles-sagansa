import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/leave_model.dart';
import '../providers/leave_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_date_range_picker.dart';
import '../widgets/modern_text_form_field.dart';

class LeaveFormPage extends StatefulWidget {
  final LeaveModel? leave;

  const LeaveFormPage({super.key, this.leave});

  @override
  LeaveFormPageState createState() => LeaveFormPageState();
}

class LeaveFormPageState extends State<LeaveFormPage> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedReason;
  late TextEditingController _notesController;
  DateTime? _fromDate;
  DateTime? _untilDate;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _reasons = [
    {
      'id': 1,
      'text': 'Cuti Menikah',
      'icon': Icons.favorite_rounded,
      'color': Colors.pink,
    },
    {
      'id': 2,
      'text': 'Sakit',
      'icon': Icons.sick_rounded,
      'color': Colors.orange,
    },
    {
      'id': 3,
      'text': 'Pulang Kampung / Izin',
      'icon': Icons.home_rounded,
      'color': Colors.blue,
    },
    {
      'id': 4,
      'text': 'Libur / Cuti Tahunan',
      'icon': Icons.beach_access_rounded,
      'color': Colors.teal,
    },
    {
      'id': 5,
      'text': 'Duka / Meninggal',
      'icon': Icons.heart_broken_rounded,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.leave?.reason;
    _notesController = TextEditingController(text: widget.leave?.notes ?? '');
    _fromDate = widget.leave?.fromDate;
    _untilDate = widget.leave?.untilDate;
  }

  int get _calculatedDays {
    if (_fromDate == null || _untilDate == null) return 0;
    final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final end = DateTime(_untilDate!.year, _untilDate!.month, _untilDate!.day);
    final diff = end.difference(start).inDays + 1;
    return diff > 0 ? diff : 0;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromDate == null || _untilDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rentang tanggal cuti')),
      );
      return;
    }

    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis / alasan cuti')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<LeaveProvider>();
      bool success;

      if (widget.leave != null) {
        success = await provider.updateLeave(
          leaveId: widget.leave!.id,
          reason: _selectedReason.toString(),
          fromDate: _fromDate!,
          untilDate: _untilDate!,
          notes: _notesController.text,
        );
      } else {
        success = await provider.submitLeave(
          reason: _selectedReason!,
          fromDate: _fromDate!,
          untilDate: _untilDate!,
          notes: _notesController.text,
        );
      }

      if (!mounted) return;

      if (success) {
        showAppSnackBar(
          context,
          widget.leave != null
              ? 'Berhasil mengupdate pengajuan cuti'
              : 'Berhasil mengajukan cuti baru',
          background: AppColors.success,
        );
        Navigator.pop(context, true);
      } else {
        final error = provider.errorMessage ?? 'Gagal menyimpan cuti';
        showAppSnackBar(
          context,
          error,
          background: Theme.of(context).colorScheme.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String? dateRangeError;
    if (_fromDate != null &&
        _untilDate != null &&
        _untilDate!.isBefore(_fromDate!)) {
      dateRangeError = 'Tanggal selesai harus setelah tanggal mulai';
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(widget.leave == null ? 'Pengajuan Cuti & Izin' : 'Edit Pengajuan Cuti'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingMD
                    .copyWith(top: AppBarInsets.top(context)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Visual Reason Selector
                      Text(
                        'Pilih Jenis / Alasan Cuti',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildReasonGrid(theme, colorScheme),

                      const SizedBox(height: 20),

                      // Section 2: Date Range Picker & Duration Banner
                      Text(
                        'Rentang Waktu Cuti',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ModernDateRangePicker(
                        startDate: _fromDate,
                        endDate: _untilDate,
                        onDateRangeSelected: (start, end) {
                          setState(() {
                            _fromDate = start;
                            _untilDate = end;
                          });
                        },
                        minDate: DateTime.now().subtract(const Duration(days: 30)),
                        maxDate: DateTime.now().add(const Duration(days: 365)),
                        errorText: dateRangeError,
                      ),

                      if (_calculatedDays > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: AppSpacing.borderRadiusMD,
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 20, color: colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Total Durasi Cuti:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: AppSpacing.borderRadiusMD,
                                ),
                                child: Text(
                                  '$_calculatedDays Hari',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Section 3: Notes / Catatan
                      Text(
                        'Catatan / Penjelasan Tambahan',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ModernTextFormField(
                        labelText: 'Catatan (opsional)',
                        controller: _notesController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        validator: (value) {
                          if (value != null && value.length > 500) {
                            return 'Catatan tidak boleh lebih dari 500 karakter';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Action Bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.sm,
                top: AppSpacing.sm,
              ),
              child: ModernButton(
                text: widget.leave == null ? 'Kirim Pengajuan' : 'Update Pengajuan',
                onPressed: _isLoading ? null : _submitForm,
                isLoading: _isLoading,
                icon: Icons.send_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonGrid(ThemeData theme, ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _reasons.length,
      itemBuilder: (context, index) {
        final reason = _reasons[index];
        final id = reason['id'] as int;
        final text = reason['text'] as String;
        final icon = reason['icon'] as IconData;
        final color = reason['color'] as Color;
        final isSelected = _selectedReason == id;

        return GestureDetector(
          onTap: () => setState(() => _selectedReason = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerLow,
              borderRadius: AppSpacing.borderRadiusMD,
              border: Border.all(
                color: isSelected ? color : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? color : colorScheme.onSurfaceVariant,
                ),
                AppSpacing.gapHorizontalSM,
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? color : colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: color,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

