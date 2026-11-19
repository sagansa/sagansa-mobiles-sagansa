import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/salary_service.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';

class SalaryPayPage extends StatefulWidget {
  final int salaryId;
  const SalaryPayPage({super.key, required this.salaryId});

  @override
  State<SalaryPayPage> createState() => _SalaryPayPageState();
}

class _SalaryPayPageState extends State<SalaryPayPage> {
  final SalaryService _service = SalaryService();
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _paidAmountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  Map<String, dynamic>? _info;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await _service.getPaymentInfo(widget.salaryId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _isLoading = false;
        final defaults = info['defaults'] ?? {};
        _paidAmountCtrl.text = FormatUtils.formatAmount(
            _parseInt(defaults['suggested_paid_amount']));
        _dateCtrl.text = defaults['today'] ??
            DateTime.now().toIso8601String().substring(0, 10);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final amount = parseAmount(_paidAmountCtrl.text);
    if (amount == null || amount <= 0 || _dateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi nominal (> 0) & tanggal.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _service.paySalary(
          id: widget.salaryId, paidAmount: amount, paymentDate: _dateCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gaji berhasil dibayar.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(title: const Text('Bayar Gaji')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: Text(_error!,
                        style: TextStyle(color: colorScheme.error)),
                  ),
                )
              : _info == null
                  ? const Center(child: Text('Data tidak ditemukan.'))
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppBarInsets.top(context),
                        AppSpacing.md,
                        AppSpacing.md + context.systemBottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBankCard(theme),
                          AppSpacing.gapVerticalMD,
                          _buildBreakdownCard(theme),
                          AppSpacing.gapVerticalMD,
                          TextField(
                            controller: _paidAmountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: rupiahInputFormatters,
                            decoration: InputDecoration(
                              labelText: 'Nominal Dibayarkan',
                              prefixText: 'Rp ',
                              border: const OutlineInputBorder(),
                              helperText: _buildSelisihHelper(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          AppSpacing.gapVerticalSM,
                          TextField(
                            controller: _dateCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'Tanggal Bayar',
                                border: OutlineInputBorder()),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                _dateCtrl.text =
                                    picked.toIso8601String().substring(0, 10);
                              }
                            },
                          ),
                          AppSpacing.gapVerticalLG,
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _submit,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check),
                              label: const Text('Konfirmasi Pembayaran'),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  String? _buildSelisihHelper() {
    final breakdown = _info?['breakdown'] ?? {};
    final total = _parseInt(breakdown['total_salary']);
    final daily = _parseInt(breakdown['daily_salary_total']);
    final expected = total - daily;
    final input = parseAmount(_paidAmountCtrl.text);
    if (input == null) return null;
    final selisih = expected - input;
    if (selisih > 0) {
      return 'Kurang bayar: ${currencyFormatter.format(selisih)}';
    }
    if (selisih < 0) {
      return 'Lebih bayar: ${currencyFormatter.format(selisih.abs())}';
    }
    return 'Sesuai gaji bulanan bersih.';
  }

  Widget _buildBankCard(ThemeData theme) {
    final bank = _info?['bank'] ?? {};
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rekening Penerima',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.gapVerticalSM,
            _row('Bank', bank['bank_name']?.toString() ?? '—'),
            _row(
                'No. Rekening', bank['bank_account_number']?.toString() ?? '—'),
            _row('Atas Nama', bank['bank_account_name']?.toString() ?? '—'),
            _row('Biaya Admin',
                currencyFormatter.format(_parseInt(bank['admin_fee']))),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(ThemeData theme) {
    final b = _info?['breakdown'] ?? {};
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rincian Gaji',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _row('Gaji Utama (A)',
                currencyFormatter.format(_parseInt(b['base_salary']))),
            _row('Denda Keterlambatan',
                '- ${currencyFormatter.format(_parseInt(b['late_penalties']))}'),
            _row('Denda Manual',
                '- ${currencyFormatter.format(_parseInt(b['manual_penalties']))}'),
            _row('Cicilan Kasbon',
                '- ${currencyFormatter.format(_parseInt(b['loan_installments']))}'),
            _row('Gaji Bulanan Bersih',
                currencyFormatter.format(_parseInt(b['monthly_part']))),
            _row('Gaji Harian (B)',
                currencyFormatter.format(_parseInt(b['daily_salary_total']))),
            const Divider(),
            _row('Total Gaji (A+Pengurangan+B)',
                currencyFormatter.format(_parseInt(b['total_salary']))),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Parse nilai numerik dari API (bisa int, double, atau String) ke int.
  /// Aman terhadap null dan tipe tak terduga.
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
