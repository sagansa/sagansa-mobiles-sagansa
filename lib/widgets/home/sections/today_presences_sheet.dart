import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/home_dashboard_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../safe_bottom_bar.dart';

/// Membuka bottom sheet daftar presensi hari ini (admin).
///
/// Membaca state dari [HomeDashboardProvider.adminPresence].
Future<void> showTodayPresencesSheet(BuildContext context) async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final adminPresence =
      context.read<HomeDashboardProvider>().adminPresence;
  final presences = adminPresence.todayPresences;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (sheetContext, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Presensi Hari Ini',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    adminPresence.lateCount > 0
                        ? '${presences.length} karyawan telah presensi • ${adminPresence.lateCount} terlambat'
                        : '${presences.length} karyawan telah presensi',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: adminPresence.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : presences.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada presensi hari ini.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            // + inset sistem bawah agar item terakhir tidak
                            // tertutup home indicator / gesture bar.
                            padding: AppSpacing.paddingMD.copyWith(
                              bottom: AppSpacing.md +
                                  sheetContext.systemBottomInset,
                            ),
                            itemCount: presences.length,
                            itemBuilder: (itemContext, idx) {
                              final presence =
                                  presences[idx] as Map<String, dynamic>;
                              return _PresenceTile(presence: presence);
                            },
                          ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _PresenceTile extends StatelessWidget {
  final Map<String, dynamic> presence;
  const _PresenceTile({required this.presence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ── Nama (robust terhadap berbagai struktur) ──
    final userName = presence['user'] is Map
        ? (presence['user']['name'] ?? presence['user']['full_name'])
        : (presence['employee'] is Map
            ? (presence['employee']['name'] ??
                presence['employee']['full_name'])
            : (presence['created_by'] is Map
                ? (presence['created_by']['name'] ??
                    presence['created_by']['full_name'])
                : presence['user_name'] ?? presence['name']));
    final name = (userName?.toString().isNotEmpty == true)
        ? userName.toString()
        : '-';

    // ── Store: prioritas nickname ──
    final storeMap =
        presence['store'] is Map ? presence['store'] as Map : null;
    final store = storeMap != null
        ? (storeMap['nickname']?.toString().isNotEmpty == true
            ? storeMap['nickname']
            : storeMap['name'])?.toString()
        : null;
    final storeText = (store?.isNotEmpty == true) ? store! : '-';

    final clockInRaw = presence['clock_in']?.toString();
    final clockOutRaw = presence['clock_out']?.toString();

    // ── Status telat masuk ──
    bool inLate;
    if (presence['is_late'] != null) {
      inLate = _toBool(presence['is_late']);
    } else if (presence['late'] != null) {
      inLate = _toBool(presence['late']);
    } else {
      inLate = _isLateTime(clockInRaw, '09:00');
    }

    // ── Status telat keluar (pulang) ──
    bool outLate;
    if (presence['is_late_out'] != null) {
      outLate = _toBool(presence['is_late_out']);
    } else if (presence['out_late'] != null) {
      outLate = _toBool(presence['out_late']);
    } else {
      outLate = _isLateTime(clockOutRaw, '17:00');
    }

    final inColor = inLate ? colorScheme.error : AppColors.success;
    final outColor = outLate ? AppColors.success : colorScheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.person,
                  size: 20, color: colorScheme.onSurfaceVariant),
            ),
            AppSpacing.gapHorizontalMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    storeText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (clockInRaw != null)
                  Text(
                    'In: $clockInRaw',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: inColor,
                    ),
                  ),
                if (clockOutRaw != null)
                  Text(
                    'Out: $clockOutRaw',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: outColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _toBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }
  return false;
}

/// Mengembalikan true bila [rawTime] (format HH:mm atau HH:mm:ss) lebih dari
/// [threshold] (format HH:mm). Bila waktu tidak valid, anggap tidak telat.
bool _isLateTime(String? rawTime, String threshold) {
  if (rawTime == null || rawTime.isEmpty) return false;
  final t = rawTime.split(':');
  final lim = threshold.split(':');
  if (t.length < 2 || lim.length < 2) return false;
  final th = int.tryParse(t[0]) ?? 0;
  final tm = int.tryParse(t[1]) ?? 0;
  final lh = int.tryParse(lim[0]) ?? 0;
  final lm = int.tryParse(lim[1]) ?? 0;
  final cur = th * 60 + tm;
  final limit = lh * 60 + lm;
  return cur > limit;
}
