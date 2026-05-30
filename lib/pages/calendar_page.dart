import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../models/presence_model.dart';
import '../models/leave_model.dart';
import '../services/leave_service.dart';
import '../widgets/modern_bottom_nav.dart';

class CalendarPage extends StatefulWidget {
  final List<PresenceModel> presences;

  const CalendarPage({super.key, required this.presences});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late List<Appointment> _appointments;
  List<Leave> _leaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final leaves = await LeaveService().getLeaves();
      setState(() {
        _leaves = leaves;
        _appointments = _getAppointments();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data')),
      );
    }
  }

  List<Appointment> _getAppointments() {
    List<Appointment> appointments = [];

    for (var presence in widget.presences) {
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

    for (var leave in _leaves) {
      appointments.add(Appointment(
        startTime: DateTime(leave.fromDate.year, leave.fromDate.month,
            leave.fromDate.day, 0, 0, 0),
        endTime: DateTime(leave.untilDate.year, leave.untilDate.month,
            leave.untilDate.day, 23, 59, 59),
        subject: 'Cuti: ${leave.reasonText}',
        notes: leave.notes ?? '',
        color: _getLeaveStatusColor(leave.status),
        isAllDay: true,
        resourceIds: ['leave'],
      ));
    }

    return appointments;
  }

  Color _getStatusColor(PresenceModel presence) {
    if (presence.checkOutStatus == 'tidak_absen') {
      return Colors.red;
    } else if (presence.checkInStatus == 'terlambat') {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  Color _getLeaveStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange.withValues(alpha: 0.7);
      case 2:
        return Colors.green.withValues(alpha: 0.7);
      case 3:
        return Colors.red.withValues(alpha: 0.7);
      default:
        return Colors.grey.withValues(alpha: 0.7);
    }
  }

  void _onTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.calendarCell) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            constraints: const BoxConstraints(
              minHeight: 200,
              maxHeight: 300,
            ),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(details.date!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _getContentForDate(details.date!),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _getContentForDate(DateTime date) {
    if (_leaves.any((l) =>
        _isSameDay(date, l.fromDate) ||
        _isSameDay(date, l.untilDate) ||
        (date.isAfter(l.fromDate) && date.isBefore(l.untilDate)))) {
      return _buildLeaveDetails(date);
    }

    if (widget.presences.any((p) {
      final checkInTime = DateTime.parse(p.checkIn).toLocal();
      return _isSameDay(date, checkInTime);
    })) {
      return _buildPresenceDetails(date);
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Text(
          'Tidak ada data untuk tanggal ini',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildPresenceDetails(DateTime date) {
    try {
      final presence = widget.presences.firstWhere((p) {
        final checkInTime = DateTime.parse(p.checkIn).toLocal();
        return _isSameDay(date, checkInTime);
      });

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              presence.store,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Shift: ${presence.shiftStore}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Check In',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatDateTime(DateTime.parse(presence.checkIn))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: presence
                            .getStatusColor(presence.checkInStatus)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        presence.getStatusText(presence.checkInStatus),
                        style: TextStyle(
                          color:
                              presence.getStatusColor(presence.checkInStatus),
                        ),
                      ),
                    ),
                  ],
                ),
                if (presence.checkOut != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Check Out',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_formatDateTime(DateTime.parse(presence.checkOut!))),
                      if (presence.checkOutStatus != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: presence
                                .getStatusColor(presence.checkOutStatus!)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            presence.getStatusText(presence.checkOutStatus!),
                            style: TextStyle(
                              color: presence
                                  .getStatusColor(presence.checkOutStatus!),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildLeaveDetails(DateTime date) {
    try {
      final leave = _leaves.firstWhere(
        (l) =>
            (date.isAfter(l.fromDate.subtract(const Duration(days: 1))) ||
                _isSameDay(date, l.fromDate)) &&
            (date.isBefore(l.untilDate.add(const Duration(days: 1))) ||
                _isSameDay(date, l.untilDate)),
      );

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cuti: ${leave.reasonText}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Status: ${leave.statusText}'),
            const SizedBox(height: 8),
            Text(
              'Tanggal: ${_formatDate(leave.fromDate)} - ${_formatDate(leave.untilDate)}',
            ),
            if (leave.notes != null && leave.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Catatan: ${leave.notes}'),
            ],
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kalender')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
      ),
      body: SfCalendar(
        view: CalendarView.month,
        dataSource: AppointmentDataSource(_appointments),
        onTap: _onTap,
        monthViewSettings: const MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
          showAgenda: true,
          agendaViewHeight: 200,
          numberOfWeeksInView: 6,
          agendaStyle: AgendaStyle(
            backgroundColor: Colors.white,
            appointmentTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            dateTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
            dayTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
        timeSlotViewSettings: const TimeSlotViewSettings(
          startHour: 0,
          endHour: 24,
          timeFormat: 'HH:mm',
          timeIntervalHeight: 60,
          timeTextStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        showDatePickerButton: true,
        allowViewNavigation: true,
        showNavigationArrow: true,
        todayHighlightColor: Theme.of(context).primaryColor,
        cellBorderColor: Colors.grey[300],
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
        presences: widget.presences,
      ),
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
