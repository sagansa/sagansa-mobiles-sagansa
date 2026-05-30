import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalaryDetailPage extends StatelessWidget {
  final Map<String, dynamic> salaryData;

  SalaryDetailPage({
    super.key,
    required this.salaryData,
  });

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Dummy data untuk contoh detail kerja harian
  final List<Map<String, dynamic>> dailyWork = [
    {
      'date': DateTime(2024, 4, 1),
      'workHours': 8,
      'overtime': 1,
      'dailyWage': 185000,
      'status': 'normal', // normal, holiday, leave, absent
    },
    {
      'date': DateTime(2024, 4, 2),
      'workHours': 8,
      'overtime': 2,
      'dailyWage': 200000,
      'status': 'normal',
    },
    // ... tambahkan data harian lainnya
  ];

  Widget _buildSummaryCard(String title, String value, {Color? valueColor}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkHoursSummary(BuildContext context) {
    final totalWorkHours = dailyWork.fold<double>(
        0, (sum, day) => sum + day['workHours'] + (day['overtime'] ?? 0));
    final totalOvertime =
        dailyWork.fold<double>(0, (sum, day) => sum + (day['overtime'] ?? 0));
    final regularHours = totalWorkHours - totalOvertime;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Jam Kerja',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        regularHours.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Jam Normal'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        totalOvertime.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text('Jam Lembur'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        totalWorkHours.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text('Total Jam'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyWorkList() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Detail Harian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dailyWork.length,
            itemBuilder: (context, index) {
              final day = dailyWork[index];
              final totalHours = day['workHours'] + (day['overtime'] ?? 0);

              return ListTile(
                title: Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(day['date']),
                ),
                subtitle: Text(
                  '${day['workHours']} jam normal + ${day['overtime']} jam lembur',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormatter.format(day['dailyWage']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '$totalHours jam',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Gaji ${DateFormat('MMMM yyyy', 'id_ID').format(salaryData['period'])}',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: _getStatusBackgroundColor(salaryData['status']),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(salaryData['status']),
                    color: _getStatusColor(salaryData['status']),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusMessage(salaryData['status']),
                    style: TextStyle(
                      color: _getStatusColor(salaryData['status']),
                    ),
                  ),
                ],
              ),
            ),
            _buildSummaryCard(
              'Total Gaji',
              currencyFormatter.format(salaryData['amount']),
              valueColor: Colors.green,
            ),
            _buildWorkHoursSummary(context),
            _buildDailyWorkList(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    return _getStatusColor(status).withValues(alpha: 0.1);
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
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
    switch (status) {
      case 'paid':
        return 'Gaji telah dibayarkan pada ${DateFormat('dd MMMM yyyy', 'id_ID').format(salaryData['paymentDate'])}';
      case 'pending':
        return 'Gaji akan dibayarkan pada akhir bulan';
      case 'processing':
        return 'Gaji sedang diproses';
      default:
        return 'Status tidak diketahui';
    }
  }
}
