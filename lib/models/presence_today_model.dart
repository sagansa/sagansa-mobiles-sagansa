class PresenceTodayModel {
  final bool hasPresence;

  PresenceTodayModel({
    required this.hasPresence,
  });

  factory PresenceTodayModel.fromJson(Map<String, dynamic> json) {
    return PresenceTodayModel(
      hasPresence: json['data']['has_presence'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': {
        'has_presence': hasPresence,
      }
    };
  }
}
