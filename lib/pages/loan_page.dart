import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/salary_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';

class LoanPage extends StatefulWidget {
  const LoanPage({super.key});

  @override
  State<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends State<LoanPage> {
  final SalaryService _salaryService = SalaryService();
  List<Map<String, dynamic>> _loans = [];
  bool _isLoading = true;
  String? _errorMessage;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await _salaryService.getSalaryHistory();
      final List<Map<String, dynamic>> loanItems = [];

      for (var salary in history) {
        try {
          final detail = await _salaryService.getSalaryDetail(salary['id']);
          final deductions = detail['deductions'] ?? {};
          final int installment = deductions['loan_installments'] ?? 0;
          if (installment > 0) {
            loanItems.add({
              'period': detail['period'],
              'period_label': detail['period_label'],
              'amount': installment,
              'status': detail['status'] == 'paid' ? 'Lunas' : 'Belum Lunas',
            });
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _loans = loanItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data kasbon: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Pinjaman Kasbon'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: textTheme.bodyLarge?.copyWith(color: colorScheme.error)),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton(
                          onPressed: _loadLoans,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _loans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 48,
                            color: AppColors.info,
                          ),
                          AppSpacing.gapVerticalMD,
                          Text(
                            'Tidak ada riwayat pinjaman kasbon.',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: AppSpacing.paddingMD
                          .copyWith(top: AppBarInsets.top(context)),
                      itemCount: _loans.length,
                      itemBuilder: (context, index) {
                        final loan = _loans[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: AppSpacing.sectionGap),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            title: Text(
                              loan['period_label'] ?? '',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Row(
                                children: [
                                  Text(
                                    'Status: ',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    loan['status'],
                                    style: textTheme.bodySmall?.copyWith(
                                      color: loan['status'] == 'Lunas' ? AppColors.success : AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Text(
                              currencyFormatter.format(loan['amount']),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
