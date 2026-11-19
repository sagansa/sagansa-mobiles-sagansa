import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/presence_model.dart';
import '../../../providers/home_dashboard_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../modern_button.dart';

/// Section presensi user (clock in / clock out / selesai) di dashboard staff.
///
/// Subscribe ke [HomeDashboardProvider.presence.todayPresence] via `context.select`.
/// Tombol clock in/out memanggil [onNavigateToPresence] yang dibawa dari parent.
class HomePresenceSection extends StatelessWidget {
  /// Callback saat tombol clock in/out ditekan (navigasi ke PresencePage).
  final VoidCallback onNavigateToPresence;

  const HomePresenceSection({super.key, required this.onNavigateToPresence});

  @override
  Widget build(BuildContext context) {
    final todayPresence = context.select<HomeDashboardProvider, PresenceModel?>(
        (p) => p.presence.todayPresence);

    if (todayPresence != null) {
      if (todayPresence.checkOut != null) {
        return _CompletedPresenceCard(
          presence: todayPresence,
          onOpenPresence: onNavigateToPresence,
        );
      }
      return _PresenceCard(
        presence: todayPresence,
        onClockOut: onNavigateToPresence,
      );
    }

    return _EmptyPresenceCard(onClockIn: onNavigateToPresence);
  }
}

Map<String, String> _splitDateTime(String dateTimeString) {
  try {
    final dateTime = DateTime.parse(dateTimeString);
    return {
      'date':
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}',
      'time':
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
    };
  } catch (_) {
    return {'date': '-', 'time': '-'};
  }
}

/// Kartu saat karyawan sedang aktif bekerja (sudah Clock In, belum Clock Out).
class _PresenceCard extends StatelessWidget {
  final PresenceModel presence;
  final VoidCallback onClockOut;

  const _PresenceCard({required this.presence, required this.onClockOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final checkInDateTime = _splitDateTime(presence.checkIn);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: AppColors.success.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Baris: Toko & Status Aktif
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: AppSpacing.borderRadiusSM,
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                      AppSpacing.gapHorizontalSM,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              presence.store.isEmpty ? 'Toko Sagansa' : presence.store,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              presence.shiftStore.isEmpty ? 'Shift Kerja' : presence.shiftStore,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: AppSpacing.borderRadiusFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'AKTIF BEKERJA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapVerticalMD,
            // Info Row: Check In & Check Out
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.3 : 0.5,
                ),
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: Row(
                children: [
                  // Sisi Check In
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check In (Masuk)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              checkInDateTime['time']!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            AppSpacing.gapHorizontalXS,
                            _StatusBadge(
                              color: presence.getStatusColor(presence.checkInStatus),
                              text: presence.getStatusText(presence.checkInStatus),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  AppSpacing.gapHorizontalSM,
                  // Sisi Check Out
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check Out (Pulang)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Belum Pulang',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapVerticalMD,
            // Tombol Clock Out
            ModernButton(
              text: 'CLOCK OUT / SELESAI KERJA',
              icon: Icons.logout_rounded,
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              onPressed: onClockOut,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu saat karyawan sudah Clock Out (kehadiran tuntas untuk hari ini).
class _CompletedPresenceCard extends StatelessWidget {
  final PresenceModel presence;
  final VoidCallback onOpenPresence;

  const _CompletedPresenceCard({
    required this.presence,
    required this.onOpenPresence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final checkInDateTime = _splitDateTime(presence.checkIn);
    final checkOutDateTime = presence.checkOut != null
        ? _splitDateTime(presence.checkOut!)
        : {'time': '-'};

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: AppSpacing.borderRadiusSM,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    AppSpacing.gapHorizontalSM,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Presensi Hari Ini Selesai',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${presence.store} • ${presence.shiftStore}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.history_rounded),
                  tooltip: 'Riwayat Presensi',
                  onPressed: onOpenPresence,
                ),
              ],
            ),
            AppSpacing.gapVerticalSM,
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.25 : 0.4,
                ),
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        AppSpacing.gapHorizontalXS,
                        Text(
                          'Masuk: ${checkInDateTime['time']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  AppSpacing.gapHorizontalSM,
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: AppColors.info,
                        ),
                        AppSpacing.gapHorizontalXS,
                        Text(
                          'Pulang: ${checkOutDateTime['time']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu saat karyawan belum Clock In hari ini.
class _EmptyPresenceCard extends StatelessWidget {
  final VoidCallback onClockIn;

  const _EmptyPresenceCard({required this.onClockIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkPrimaryContainer
                        : AppColors.primaryContainer,
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 26,
                    color: isDark
                        ? AppColors.darkPrimary
                        : AppColors.primary,
                  ),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Presensi Masuk Kerja',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Anda belum mencatat kehadiran untuk hari ini.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapVerticalMD,
            ModernButton(
              text: 'CLOCK IN SEKARANG',
              icon: Icons.login_rounded,
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.onSuccess,
              onPressed: onClockIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final String text;

  const _StatusBadge({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}
