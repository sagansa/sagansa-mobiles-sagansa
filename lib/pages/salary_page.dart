import 'package:flutter/material.dart';
import '../widgets/modern_bottom_nav.dart';
import 'package:intl/intl.dart';
import 'salary_detail_page.dart';

class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});

  @override
  _SalaryPageState createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Dummy data untuk contoh
  final List<Map<String, dynamic>> salaryHistory = [
    {
      'period': DateTime(2024, 4),
      'amount': 4850000,
      'status': 'pending', // pending, paid, processing
      'paymentDate': null,
    },
    {
      'period': DateTime(2024, 3),
      'amount': 4750000,
      'status': 'paid',
      'paymentDate': DateTime(2024, 3, 28),
    },
    {
      'period': DateTime(2024, 2),
      'amount': 4900000,
      'status': 'paid',
      'paymentDate': DateTime(2024, 2, 28),
    },
    {
      'period': DateTime(2024, 1),
      'amount': 4800000,
      'status': 'paid',
      'paymentDate': DateTime(2024, 1, 28),
    },
  ];

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

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Dibayarkan';
      case 'pending':
        return 'Menunggu';
      case 'processing':
        return 'Diproses';
      default:
        return 'Unknown';
    }
  }

  Widget _buildSalaryCard(Map<String, dynamic> salary) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SalaryDetailPage(salaryData: salary),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(salary['period']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(salary['status']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(salary['status']),
                      style: TextStyle(
                        color: _getStatusColor(salary['status']),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currencyFormatter.format(salary['amount']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (salary['paymentDate'] != null)
                    Text(
                      'Dibayar: ${DateFormat('dd/MM/yyyy').format(salary['paymentDate'])}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Gaji'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withValues(alpha: 0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gaji dibayarkan maksimum tanggal 5 setiap bulan',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: salaryHistory.length,
              itemBuilder: (context, index) {
                return _buildSalaryCard(salaryHistory[index]);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 3,
        presences: const [],
        onTap: (index) {
          if (index != 3) {
            Navigator.pushReplacementNamed(
              context,
              index == 0
                  ? '/home'
                  : index == 1
                      ? '/leave'
                      : '/calendar',
            );
          }
        },
      ),
    );
  }
}
