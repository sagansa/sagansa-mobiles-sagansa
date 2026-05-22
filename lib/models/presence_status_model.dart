class PresenceStatusModel {
  final String status;
  final bool hasCheckedIn;

  PresenceStatusModel({
    required this.status,
    required this.hasCheckedIn,
  });

  // Factory constructor to create an instance from JSON
  factory PresenceStatusModel.fromJson(Map<String, dynamic> json) {
    return PresenceStatusModel(
      status: json['status'] as String,
      hasCheckedIn: json['data']['has_checked_in'] as bool,
    );
  }

  // Method to convert an instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': {
        'has_checked_in': hasCheckedIn,
      },
    };
  }
}
