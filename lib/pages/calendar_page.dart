import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../models/leave_model.dart';
import '../models/presence_model.dart';
import '../services/closing_store_service.dart';
import '../services/leave_service.dart';
import '../services/storage_stock_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';

class CalendarPage extends StatefulWidget {
  final List<PresenceModel> presences;

  const CalendarPage({super.key, required this.presences});

  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  late List<Appointment> _allAppointments;
  List<Appointment> _filteredAppointments = [];
  List<Leave> _leaves = [];
  List<dynamic> _dailySalaries = [];
  List<dynamic> _closingStores = [];
  List<dynamic> _storageStocks = [];
  bool _isLoading = true;

  // Filter states
  bool _showPresence = true;
  bool _showLeave = true;
  bool _showSalary = true;
  bool _showClosing = true;
  bool _showStock = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        LeaveService().getLeaves(),
        ClosingStoreService().getDailySalaries(page: 1, perPage: 100),
        ClosingStoreService().getClosingStores(),
        StorageStockService().getStorageStocks(),
      ]);

      _leaves = results[0] as List<Leave>;
      final salaryResult = results[1] as Map<String, dynamic>;
      _dailySalaries = salaryResult['data'] ?? [];
      _closingStores = results[2] as List<dynamic>;
      final stockResult = results[3] as Map<String, dynamic>;
      _storageStocks = stockResult['data'] ?? [];

      setState(() {
        _allAppointments = _getAppointments();
        _filteredAppointments = _allAppointments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data kalender')),
      );
    }
  }

  List<Appointment> _getAppointments() {
    final appointments = <Appointment>[];

    // Presensi
    for (final presence in widget.presences) {
      final checkInTime = DateTime.parse(presence.checkIn).toLocal();
      final checkOutTime = presence.checkOut != null
          ? DateTime.parse(presence.checkOut!).toLocal()
          : checkInTime.add(const Duration(hours: 8));

      appointments.add(Appointment(
        startTime: checkInTime,
        endTime: checkOutTime,
        subject: 'Presensi: ${presence.store}',
        notes: presence.shiftStore,
        color: _getStatusColor(presence),
        isAllDay: false,
        resourceIds: ['presence'],
      ));
    }

    // Cuti
    for (final leave in _leaves) {
      appointments.add(Appointment(
        startTime: DateTime(leave.fromDate.year, leave.fromDate.month, leave.fromDate.day),
        endTime: DateTime(leave.untilDate.year, leave.untilDate.month, leave.untilDate.day, 23, 59, 59),
        subject: 'Cuti: ${leave.reasonText}',
        notes: leave.notes ?? '',
        color: _getLeaveStatusColor(leave.status),
        isAllDay: true,
        resourceIds: ['leave'],
      ));
    }

    // Daily Salary
    for (final salary in _dailySalaries) {
      final date = salary['date'] ?? '';
      if (date.isNotEmpty) {
        final amount = double.tryParse(salary['amount'].toString()) ?? 0;
        final employeeName = salary['created_by']?['name'] ?? 'Staff';
        final status = salary['status'];

        String statusText;
        if (status == 1 || status == '1') {
          statusText = 'Belum Dibayar';
        } else if (status == 2 || status == '2') {
          statusText = 'Sudah Dibayar';
        } else if (status == 3 || status == '3') {
          statusText = 'Siap Dibayar';
        } else {
          statusText = 'Perbaiki';
        }

        appointments.add(Appointment(
          startTime: DateTime.parse(date),
          endTime: DateTime.parse(date).add(const Duration(hours: 1)),
          subject: 'Gaji: $employeeName - Rp ${amount.toStringAsFixed(0)}',
          notes: statusText,
          color: AppColors.info,
          isAllDay: false,
          resourceIds: ['salary'],
        ));
      }
    }

    // Closing Store
    for (final closing in _closingStores) {
      final date = closing['date'] ?? '';
      if (date.isNotEmpty) {
        final storeName = closing['store']?['nickname'] ?? 'Toko';
        final amount = closing['total_cash_transfer'] ?? 0;

        appointments.add(Appointment(
          startTime: DateTime.parse(date),
          endTime: DateTime.parse(date).add(const Duration(hours: 1)),
          subject: 'Closing: $storeName',
          notes: 'Rp ${amount.toString()}',
          color: AppColors.secondary,
          isAllDay: false,
          resourceIds: ['closing'],
        ));
      }
    }

    // Storage Stock
    for (final stock in _storageStocks) {
      final date = stock['date'] ?? '';
      if (date.isNotEmpty) {
        final storeName = stock['store']?['nickname'] ?? 'Gudang';

        appointments.add(Appointment(
          startTime: DateTime.parse(date),
          endTime: DateTime.parse(date).add(const Duration(hours: 1)),
          subject: 'Stok: $storeName',
          notes: 'Laporan stok gudang',
          color: AppColors.success,
          isAllDay: false,
          resourceIds: ['stock'],
        ));
      }
    }

    return appointments;
  }

  void _applyFilters() {
    setState(() {
      _filteredAppointments = _allAppointments.where((apt) {
        final resourceId = apt.resourceIds?.first ?? '';
        if (resourceId == 'presence' && !_showPresence) return false;
        if (resourceId == 'leave' && !_showLeave) return false;
        if (resourceId == 'salary' && !_showSalary) return false;
        if (resourceId == 'closing' && !_showClosing) return false;
        if (resourceId == 'stock' && !_showStock) return false;
        return true;
      }).toList();
    });
  }

  Color _getStatusColor(PresenceModel presence) {
    if (presence.checkOutStatus == 'tidak_absen') {
      return AppColors.error;
    } else if (presence.checkInStatus == 'terlambat') {
      return AppColors.warning;
    } else {
      return AppColors.success;
    }
  }

  Color _getLeaveStatusColor(int status) {
    switch (status) {
      case 1:
        return AppColors.warning.withValues(alpha: 0.7);
      case 2:
        return AppColors.success.withValues(alpha: 0.7);
      case 3:
        return AppColors.error.withValues(alpha: 0.7);
      default:
        return AppColors.onSurfaceVariant.withValues(alpha: 0.7);
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: GlassAppBar(title: const Text('Kalender')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Kalender'),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Filter chips
            _buildFilterChips(),
            // Calendar
            Expanded(
              child: SfCalendar(
              view: CalendarView.month,
              dataSource: AppointmentDataSource(_filteredAppointments),
              monthViewSettings: MonthViewSettings(
                appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                showAgenda: true,
                agendaViewHeight: 220,
                numberOfWeeksInView: 6,
                agendaStyle: AgendaStyle(
                  backgroundColor: colorScheme.surface,
                  appointmentTextStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  dateTextStyle: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  dayTextStyle: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              appointmentBuilder: (context, calendarAppointmentDetails) {
                final appointment = calendarAppointmentDetails.appointments.first as Appointment;
                final color = appointment.color;
                final isDark = theme.brightness == Brightness.dark;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? color.withValues(alpha: 0.2)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: AppSpacing.borderRadiusMD,
                    border: Border.all(
                      color: color.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: AppSpacing.borderRadiusXS,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appointment.subject,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
              timeSlotViewSettings: TimeSlotViewSettings(
                startHour: 0,
                endHour: 24,
                timeFormat: 'HH:mm',
                timeIntervalHeight: 60,
                timeTextStyle: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              showDatePickerButton: true,
              allowViewNavigation: true,
              showNavigationArrow: true,
              todayHighlightColor: colorScheme.primary,
              cellBorderColor: colorScheme.outlineVariant,
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 1,
        onTap: (index) {},
        presences: widget.presences,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Presensi',
              color: AppColors.success,
              selected: _showPresence,
              onToggle: (value) {
                setState(() => _showPresence = value);
                _applyFilters();
              },
            ),
            AppSpacing.gapHorizontalSM,
            _buildFilterChip(
              label: 'Cuti',
              color: AppColors.warning,
              selected: _showLeave,
              onToggle: (value) {
                setState(() => _showLeave = value);
                _applyFilters();
              },
            ),
            AppSpacing.gapHorizontalSM,
            _buildFilterChip(
              label: 'Gaji',
              color: AppColors.info,
              selected: _showSalary,
              onToggle: (value) {
                setState(() => _showSalary = value);
                _applyFilters();
              },
            ),
            AppSpacing.gapHorizontalSM,
            _buildFilterChip(
              label: 'Closing',
              color: AppColors.secondary,
              selected: _showClosing,
              onToggle: (value) {
                setState(() => _showClosing = value);
                _applyFilters();
              },
            ),
            AppSpacing.gapHorizontalSM,
            _buildFilterChip(
              label: 'Stok',
              color: AppColors.success,
              selected: _showStock,
              onToggle: (value) {
                setState(() => _showStock = value);
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required bool selected,
    required Function(bool) onToggle,
  }) {
    return FilterChip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w500,
      ),
      selected: selected,
      onSelected: onToggle,
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return appointments![index].startTime;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].endTime;
  }

  @override
  String getSubject(int index) {
    return appointments![index].subject;
  }

  @override
  Color getColor(int index) {
    return appointments![index].color;
  }

  @override
  bool isAllDay(int index) {
    return appointments![index].isAllDay;
  }
}
