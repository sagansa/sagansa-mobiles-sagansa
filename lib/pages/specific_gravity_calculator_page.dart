import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/specific_gravity_record.dart';
import '../services/specific_gravity/specific_gravity_database.dart';
import '../theme/app_spacing.dart';
import '../utils/specific_gravity_calc.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/modern_button.dart';

/// Halaman kalkulator Berat Jenis untuk role storage-staff.
class SpecificGravityCalculatorPage extends StatefulWidget {
  const SpecificGravityCalculatorPage({super.key});

  @override
  State<SpecificGravityCalculatorPage> createState() =>
      _SpecificGravityCalculatorPageState();
}

class _SpecificGravityCalculatorPageState
    extends State<SpecificGravityCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _gramPerLiterController = TextEditingController();
  final SpecificGravityDatabase _db = SpecificGravityDatabase();

  SpecificGravityResult? _result;
  List<SpecificGravityRecord> _records = [];
  bool _isSaving = false;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _gramPerLiterController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final records = await _db.getAllRecords();
    if (mounted) {
      setState(() => _records = records);
    }
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final gramPerLiter = double.parse(_gramPerLiterController.text);
    final result = calculateSpecificGravity(gramPerLiter);
    setState(() => _result = result);
  }

  Future<void> _save() async {
    if (_result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hitung terlebih dahulu sebelum simpan.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final record = SpecificGravityRecord.create(
        gramPerLiter: _result!.gramPerLiter,
        totalKg: _result!.totalKg,
        additionalGram: _result!.additionalGram,
      );
      await _db.insertRecord(record);
      await _loadRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Riwayat berhasil disimpan.')),
        );
        _gramPerLiterController.clear();
        setState(() => _result = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan riwayat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteRecord(String id) async {
    await _db.deleteRecord(id);
    await _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // extendBody tetap false: jika true, konten bawah form tertutup bar aksi
      // (bar sudah meng-handle system inset sendiri lewat SafeBottomBar).
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Kalkulator Berat Jenis'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMD.copyWith(
          top: AppBarInsets.top(context),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _gramPerLiterController,
                decoration: const InputDecoration(
                  labelText: 'Gram per Liter',
                  suffixText: 'g/L',
                  helperText: 'Masukkan angka desimal (cth 906.5)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d?')),
                ],
                validator: (val) {
                  final value = double.tryParse(val ?? '');
                  if (value == null || value <= 0) {
                    return 'Masukkan angka lebih besar dari 0';
                  }
                  return null;
                },
              ),
              AppSpacing.gapVerticalMD,
              ModernButton(
                text: 'Hitung',
                onPressed: _calculate,
                icon: Icons.calculate_outlined,
              ),
              if (_result != null) ...[
                AppSpacing.gapVerticalMD,
                Card(
                  elevation: 0,
                  color: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusLG,
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: AppSpacing.paddingMD,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hasil Perhitungan',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSpacing.gapVerticalSM,
                        Text(
                          'Total: ${_result!.totalKgFormatted} kg',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        AppSpacing.gapVerticalXS,
                        Text(
                          'Tambahan: ${_result!.additionalGramFormatted} gram',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSpacing.gapVerticalXS,
                        Text(
                          '${kSpecificGravityVolumeLiters.toStringAsFixed(0)} '
                          'liter × ${_result!.gramPerLiter.toStringAsFixed(1)} g/L',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              AppSpacing.gapVerticalLG,
              Text(
                'Riwayat',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.gapVerticalSM,
              _buildHistoryList(textTheme, colorScheme),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHistoryList(TextTheme textTheme, ColorScheme colorScheme) {
    if (_records.isEmpty) {
      return Text(
        'Belum ada riwayat.',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _records.length,
      separatorBuilder: (_, __) => AppSpacing.gapVerticalXS,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusLG,
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            title: Text(
              '${record.gramPerLiter.toStringAsFixed(1)} g/L → '
              '${record.totalKgFormatted} kg',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Tambahan ${record.additionalGramFormatted} g • '
              '${_dateFormat.format(record.timestamp)}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              tooltip: 'Hapus',
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: () => _deleteRecord(record.id),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return GlassContainer.bottomBar(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: ModernButton(
        text: 'Simpan',
        onPressed: _isSaving ? null : _save,
        isLoading: _isSaving,
        icon: Icons.save_outlined,
      ),
    );
  }
}
