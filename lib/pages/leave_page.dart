import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/leave_model.dart';
import '../services/leave_service.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/modern_fab.dart';
import 'leave_form_page.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  _LeavePageState createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  List<Leave> _leaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    try {
      final leaves = await LeaveService().getLeaves();
      setState(() {
        _leaves = leaves;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data cuti')),
      );
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange; // Pending
      case 2:
        return Colors.green; // Approved
      case 3:
        return Colors.red; // Rejected
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaves,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _leaves.length,
                itemBuilder: (context, index) {
                  final leave = _leaves[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        if (leave.status == 1) {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LeaveFormPage(leave: leave),
                            ),
                          );
                          if (result == true) {
                            _loadLeaves();
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    leave.reasonText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(leave.status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    leave.statusText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.date_range,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('dd MMM yyyy').format(leave.fromDate)} - ${DateFormat('dd MMM yyyy').format(leave.untilDate)}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            if (leave.notes != null &&
                                leave.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.notes,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      leave.notes!,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            Navigator.pop(context);
          }
        },
      ),
      floatingActionButton: CustomFAB(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaveFormPage()),
          );
          if (result == true) {
            _loadLeaves();
          }
        },
        icon: Icons.event_busy,
        tooltip: 'Tambah Cuti',
      ),
    );
  }
}
