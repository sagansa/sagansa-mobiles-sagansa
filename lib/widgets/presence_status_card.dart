import 'package:flutter/material.dart';
import '../services/presence_service.dart';

class PresenceStatusCard extends StatelessWidget {
  const PresenceStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Cek apakah sudah lewat jam 6 pagi hari ini
    final now = DateTime.now();
    final sixAM = DateTime(now.year, now.month, now.day, 6, 0);
    final isAfterSixAM = now.isAfter(sixAM);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: PresenceService.getUserPresence(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Gagal memuat status presensi',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Tidak ada data presensi'));
            }

            final today = snapshot.data!['today'];
            final hasCheckIn = today != null && today['check_in'] != null;

            // Jika belum jam 6 pagi dan tidak ada check-in, tampilkan pesan khusus
            if (!isAfterSixAM && !hasCheckIn) {
              return const Center(
                child: Text(
                  'Status presensi akan tersedia mulai jam 06:00',
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Jika sudah lewat jam 6 pagi dan belum ada presensi
            if (isAfterSixAM && !hasCheckIn) {
              return const Center(
                child: Text(
                  'Belum ada presensi untuk hari ini',
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Tampilkan status presensi jika sudah ada data
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Presensi Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusRow('Check In', today['check_in'] ?? '-',
                    today['check_in_status']),
                const SizedBox(height: 8),
                _buildStatusRow('Check Out', today['check_out'] ?? '-',
                    today['check_out_status']),
                if (today['late_minutes'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Keterlambatan: ${today['late_minutes'].toString()} menit',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String time, String? status) {
    Color statusColor = Colors.grey;
    if (status == 'tepat_waktu') {
      statusColor = Colors.green;
    } else if (status == 'terlambat') {
      statusColor = Colors.red;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            Text(time),
            if (status != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
