class CalendarModel {
  final String status;
  final CalendarData data;

  CalendarModel({
    required this.status,
    required this.data,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      status: json['status'] ?? '',
      data: CalendarData.fromJson(json['data'] ?? {}),
    );
  }
}

class CalendarData {
  final String currentDate;
  final String startDate;
  final String endDate;
  final List<CalendarEvent> events;

  CalendarData({
    required this.currentDate,
    required this.startDate,
    required this.endDate,
    required this.events,
  });

  factory CalendarData.fromJson(Map<String, dynamic> json) {
    return CalendarData(
      currentDate: json['current_date'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => CalendarEvent.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class CalendarEvent {
  final int id;
  final String type;
  final String date;
  final String store;
  final String shift;
  final String checkIn;
  final String? checkOut;
  final String status;
  final String color;

  CalendarEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.store,
    required this.shift,
    required this.checkIn,
    this.checkOut,
    required this.status,
    required this.color,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      date: json['date'] ?? '',
      store: json['store'] ?? '',
      shift: json['shift'] ?? '',
      checkIn: json['check_in'] ?? '',
      checkOut: json['check_out'],
      status: json['status'] ?? '',
      color: json['color'] ?? '',
    );
  }
}
