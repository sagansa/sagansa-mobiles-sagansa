class Leave {
  final int id;
  final int reason;
  final String reasonText;
  final DateTime fromDate;
  final DateTime untilDate;
  final int status;
  final String statusText;
  final String? notes;
  final CreatedBy createdBy;
  final dynamic approvedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Leave({
    required this.id,
    required this.reason,
    required this.reasonText,
    required this.fromDate,
    required this.untilDate,
    required this.status,
    required this.statusText,
    this.notes,
    required this.createdBy,
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    return Leave(
      id: json['id'],
      reason: int.tryParse(json['reason']?.toString() ?? '0') ?? 0,
      reasonText: json['reason_text'] ?? '',
      fromDate: DateTime.parse(json['from_date']),
      untilDate: DateTime.parse(json['until_date']),
      status: int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      statusText: json['status_text'] ?? '',
      notes: json['notes'],
      createdBy: CreatedBy.fromJson(json['created_by']),
      approvedBy: json['approved_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class CreatedBy {
  final int id;
  final String name;

  CreatedBy({
    required this.id,
    required this.name,
  });

  factory CreatedBy.fromJson(Map<String, dynamic> json) {
    return CreatedBy(
      id: json['id'],
      name: json['name'],
    );
  }
}
