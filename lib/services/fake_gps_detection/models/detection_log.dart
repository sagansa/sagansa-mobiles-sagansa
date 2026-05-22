import 'location_data.dart';
import 'validation_result.dart';
import 'detection_result.dart';

/// Log entry untuk audit trail deteksi GPS palsu
class DetectionLog {
  final String id;
  final String userId;
  final DateTime timestamp;
  final LocationData location;
  final ValidationResult result;
  final String deviceInfo;
  final Map<String, dynamic> detectionDetails;

  const DetectionLog({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.location,
    required this.result,
    required this.deviceInfo,
    this.detectionDetails = const {},
  });

  factory DetectionLog.create({
    required String userId,
    required LocationData location,
    required ValidationResult result,
    required String deviceInfo,
    Map<String, dynamic> detectionDetails = const {},
  }) {
    return DetectionLog(
      id: _generateId(),
      userId: userId,
      timestamp: DateTime.now(),
      location: location,
      result: result,
      deviceInfo: deviceInfo,
      detectionDetails: detectionDetails,
    );
  }

  factory DetectionLog.fromJson(Map<String, dynamic> json) {
    return DetectionLog(
      id: json['id'],
      userId: json['userId'],
      timestamp: DateTime.parse(json['timestamp']),
      location: LocationData.fromJson(json['location']),
      result: ValidationResult(
        isValid: json['result']['isValid'],
        riskScore: json['result']['riskScore']?.toDouble() ?? 0.0,
        flags: (json['result']['flags'] as List?)
                ?.map((f) => DetectionFlag.values.firstWhere(
                      (flag) => flag.name == f,
                      orElse: () => DetectionFlag.mockLocationEnabled,
                    ))
                .toList() ??
            [],
        reason: json['result']['reason'] ?? '',
        validatedAt: DateTime.parse(json['result']['validatedAt']),
        metadata: Map<String, dynamic>.from(json['result']['metadata'] ?? {}),
      ),
      deviceInfo: json['deviceInfo'],
      detectionDetails:
          Map<String, dynamic>.from(json['detectionDetails'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'location': location.toJson(),
      'result': {
        'isValid': result.isValid,
        'riskScore': result.riskScore,
        'flags': result.flags.map((f) => f.name).toList(),
        'reason': result.reason,
        'validatedAt': result.validatedAt.toIso8601String(),
        'metadata': result.metadata,
      },
      'deviceInfo': deviceInfo,
      'detectionDetails': detectionDetails,
    };
  }

  static String _generateId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'det_${timestamp}_$random';
  }

  @override
  String toString() {
    return 'DetectionLog(id: $id, user: $userId, valid: ${result.isValid})';
  }
}
