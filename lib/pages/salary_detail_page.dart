import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/salary_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';
import 'salary_pay_page.dart';

class SalaryDetailPage extends StatefulWidget {
  final int salaryId;
  final String? userName;

  const SalaryDetailPage({
    super.key,
    required this.salaryId,
    this.userName,
  });

  @override
  State<SalaryDetailPage> createState() => _SalaryDetailPageState();
}

class _SalaryDetailPageState extends State<SalaryDetailPage> {
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final SalaryService _salaryService = SalaryService();
  Map<String, dynamic>? salaryDetail;
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadSalaryDetail();
  }

  Future<void> _loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        if (mounted) {
          setState(() {
            _isAdmin =
                List<String>.from(userData['roles'] ?? []).contains('admin');
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSalaryDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _salaryService.getSalaryDetail(widget.salaryId);
      if (!mounted) return;
      setState(() {
        salaryDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat rincian gaji: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveSalary() async {
    try {
      await _salaryService.approveSalary(widget.salaryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slip di-approve.')),
      );
      _loadSalaryDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value,
      {Color? valueColor}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapVerticalSM,
            Text(
              value,
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu informasi nilai yang ditransfer ke karyawan.
  /// Hanya tampil bila slip sudah dibayar (paid_amount != null).
  Widget _buildTransferCard(BuildContext context) {
    if (salaryDetail == null) return const SizedBox.shrink();

    final dynamic paidAmountRaw = salaryDetail!['paid_amount'];
    final dynamic paymentDateRaw = salaryDetail!['paymentDate'];

    // Hanya render bila ada nilai yang dibayarkan.
    if (paidAmountRaw == null) return const SizedBox.shrink();

    final int paidAmount = _parseInt(paidAmountRaw);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String tanggalText = '-';
    if (paymentDateRaw != null) {
      final DateTime? dt = DateTime.tryParse(paymentDateRaw.toString());
      if (dt != null) {
        tanggalText = DateFormat('d MMMM yyyy', 'id_ID').format(dt);
      }
    }

    // Selisih antara nominal transfer dengan bagian gaji BULANAN saja.
    // Gaji harian dibayar terpisah (tunai via closing store), jadi tidak
    // dibandingkan dengan paid_amount. Mencegah false "kurang bayar" sebesar
    // gaji harian padahal sebenarnya sudah pas.
    //   gaji_bulanan = total_salary (THP) - daily_salary_total
    final int totalSalary = _parseInt(salaryDetail!['amount']);
    final int dailySalaryTotal = _parseInt(salaryDetail!['daily_salary_total']);
    final int gajiBulanan = totalSalary - dailySalaryTotal;
    final int selisih = gajiBulanan - paidAmount;
    String selisihText = '';
    Color selisihColor = colorScheme.onSurfaceVariant;
    if (selisih > 0) {
      selisihText = 'Kurang bayar ${currencyFormatter.format(selisih)}';
      selisihColor = colorScheme.error;
    } else if (selisih < 0) {
      selisihText = 'Lebih bayar ${currencyFormatter.format(selisih.abs())}';
      selisihColor = AppColors.warning;
    }

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingMD,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          borderRadius: AppSpacing.borderRadiusMD,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_balance, color: AppColors.success, size: 20),
              AppSpacing.gapHorizontalSM,
              Text(
                'Nilai Ditransfer',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
            AppSpacing.gapVerticalSM,
            Text(
              currencyFormatter.format(paidAmount),
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            AppSpacing.gapVerticalSM,
            Row(
              children: [
                Icon(Icons.event, size: 16, color: AppColors.info),
                AppSpacing.gapHorizontalXS,
                Text(
                  'Ditransfer $tanggalText',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (selisihText.isNotEmpty) ...[
              AppSpacing.gapVerticalXS,
              Text(
                selisihText,
                style: textTheme.bodySmall?.copyWith(
                    color: selisihColor, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(BuildContext context) {
    if (salaryDetail == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    final int baseSalary = _parseInt(salaryDetail!['base_salary']);
    final int dailySalaryTotal = _parseInt(salaryDetail!['daily_salary_total']);
    final Map<String, dynamic> deductions = salaryDetail!['deductions'] ?? {};

    final int latePenalties = _parseInt(deductions['late_penalties']);
    final int manualPenalties = _parseInt(deductions['manual_penalties']);
    final int loanInstallments = _parseInt(deductions['loan_installments']);
    final int totalSalary = _parseInt(salaryDetail!['amount']);

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rincian Komponen Gaji',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildRowItem(
                'Gaji Utama Tenur (A)', currencyFormatter.format(baseSalary)),
            _buildRowItem('Total Gaji Harian (B)',
                currencyFormatter.format(dailySalaryTotal),
                isAddition: true),
            if (latePenalties > 0)
              _buildRowItem('Denda Keterlambatan',
                  '- ${currencyFormatter.format(latePenalties)}',
                  isDeduction: true),
            if (manualPenalties > 0)
              _buildRowItem('Denda Manual',
                  '- ${currencyFormatter.format(manualPenalties)}',
                  isDeduction: true),
            if (loanInstallments > 0)
              _buildRowItem('Cicilan Kasbon',
                  '- ${currencyFormatter.format(loanInstallments)}',
                  isDeduction: true),
            const Divider(height: 24),
            _buildRowItem('Total Gaji Akhir (A - Potongan + B)',
                currencyFormatter.format(totalSalary),
                isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRowItem(String label, String value,
      {bool isAddition = false,
      bool isDeduction = false,
      bool isBold = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    Color valColor = colorScheme.onSurface;
    if (isAddition) valColor = AppColors.success;
    if (isDeduction) valColor = colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          AppSpacing.gapHorizontalSM,
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
        appBar: GlassAppBar(title: const Text('Detail Gaji')),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLG,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!,
                    style: TextStyle(color: colorScheme.error)),
                AppSpacing.gapVerticalMD,
                ElevatedButton(
                  onPressed: _loadSalaryDetail,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (salaryDetail == null) {
      return const Scaffold(
        body: Center(child: Text('Data tidak ditemukan.')),
      );
    }

    final DateTime periodDate = _resolvePeriodDate(salaryDetail!['period']);

    return Scaffold(
      appBar: GlassAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userName ?? salaryDetail!['user_name'] ?? '',
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Slip Gaji ${DateFormat('MMMM yyyy', 'id_ID').format(periodDate)}',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: context.systemBottomInset,
        ),
        child: Column(
          children: [
            Container(
              padding: AppSpacing.paddingMD,
              color: _getStatusBackgroundColor(
                  salaryDetail!['status'], colorScheme),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(salaryDetail!['status']),
                    color:
                        _getStatusColor(salaryDetail!['status'], colorScheme),
                  ),
                  AppSpacing.gapHorizontalSM,
                  Expanded(
                    child: Text(
                      _getStatusMessage(salaryDetail!['status']),
                      style: textTheme.bodyMedium?.copyWith(
                        color: _getStatusColor(
                            salaryDetail!['status'], colorScheme),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSummaryCard(
              context,
              'Total Gaji Bersih (THP)',
              currencyFormatter.format(_parseInt(salaryDetail!['amount'])),
              valueColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.success
                  : AppColors.success,
            ),
            _buildTransferCard(context),
            _buildBreakdownCard(context),
            if (_isAdmin) ...[
              AppSpacing.gapVerticalMD,
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    if (salaryDetail!['status'] == 'draft')
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _approveSalary,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve Slip'),
                        ),
                      ),
                    if (salaryDetail!['status'] == 'processing')
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SalaryPayPage(salaryId: widget.salaryId),
                              ),
                            ).then((ok) {
                              if (ok == true) _loadSalaryDetail();
                            });
                          },
                          icon: const Icon(Icons.payments),
                          label: const Text('Bayar Gaji'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            AppSpacing.gapVerticalLG,
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    switch (status) {
      case 'draft':
        return isDark ? AppColors.darkOnSurfaceVariant : colorScheme.outline;
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.info;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  Color _getStatusBackgroundColor(String status, ColorScheme colorScheme) {
    return _getStatusColor(status, colorScheme).withValues(alpha: 0.1);
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return Icons.edit_note;
      case 'paid':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.access_time;
      case 'processing':
        return Icons.sync;
      default:
        return Icons.info_outline;
    }
  }

  String _getStatusMessage(String status) {
    final DateTime? paymentDate = salaryDetail!['paymentDate'] != null
        ? DateTime.parse(salaryDetail!['paymentDate'])
        : null;

    switch (status) {
      case 'draft':
        return 'Slip gaji masih draft, menunggu persetujuan.';
      case 'paid':
        return 'Gaji telah ditransfer pada ${paymentDate != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(paymentDate) : '-'}';
      case 'pending':
        return 'Gaji bulanan Anda masih berstatus draft/menunggu persetujuan.';
      case 'processing':
        return 'Gaji sedang diproses untuk pembayaran.';
      default:
        return 'Status gaji tidak diketahui.';
    }
  }

  /// Resolve salary period date: jika tanggal >= 26 (cutoff),
  /// bulan gaji adalah bulan berikutnya (e.g. 26 Mei → Juni).
  DateTime _resolvePeriodDate(dynamic period) {
    final dt = DateTime.parse(period.toString());
    if (dt.day >= 26) {
      return DateTime(dt.year, dt.month + 1, 1);
    }
    return DateTime(dt.year, dt.month, 1);
  }

  /// Parse nilai numerik dari API (bisa int, double, atau String) ke int.
  /// Aman terhadap null dan tipe tak terduga.
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
