import 'dart:convert';
import '../models/models.dart';

/// Utility class untuk serialisasi dan deserialisasi JSON
class JsonUtils {
  /// Encode object ke JSON string
  static String encodeToJson(dynamic object) {
    try {
      return jsonEncode(object);
    } catch (e) {
      throw Exception('Failed to encode object to JSON: $e');
    }
  }

  /// Decode JSON string ke Map
  static Map<String, dynamic> decodeFromJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw Exception('JSON is not a Map<String, dynamic>');
      }
    } catch (e) {
      throw Exception('Failed to decode JSON string: $e');
    }
  }

  /// Serialize LocationData ke JSON string
  static String serializeLocationData(LocationData locationData) {
    return encodeToJson(locationData.toJson());
  }

  /// Deserialize JSON string ke LocationData
  static LocationData deserializeLocationData(String jsonString) {
    final json = decodeFromJson(jsonString);
    return LocationData.fromJson(json);
  }

  /// Serialize ValidationResult ke JSON string
  static String serializeValidationResult(ValidationResult result) {
    final json = {
      'isValid': result.isValid,
      'riskScore': result.riskScore,
      'flags': result.flags.map((f) => f.name).toList(),
      'reason': result.reason,
      'validatedAt': result.validatedAt.toIso8601String(),
      'metadata': result.metadata,
    };
    return encodeToJson(json);
  }

  /// Deserialize JSON string ke ValidationResult
  static ValidationResult deserializeValidationResult(String jsonString) {
    final json = decodeFromJson(jsonString);

    final flags = (json['flags'] as List?)
            ?.map((flagName) => DetectionFlag.values.firstWhere(
                  (flag) => flag.name == flagName,
                  orElse: () => DetectionFlag.mockLocationEnabled,
                ))
            .toList() ??
        [];

    return ValidationResult(
      isValid: json['isValid'] ?? false,
      riskScore: (json['riskScore'] ?? 0.0).toDouble(),
      flags: flags,
      reason: json['reason'] ?? '',
      validatedAt: DateTime.parse(json['validatedAt']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  /// Serialize DetectionLog ke JSON string
  static String serializeDetectionLog(DetectionLog log) {
    final json = {
      'id': log.id,
      'userId': log.userId,
      'timestamp': log.timestamp.toIso8601String(),
      'location': log.location.toJson(),
      'result': {
        'isValid': log.result.isValid,
        'riskScore': log.result.riskScore,
        'flags': log.result.flags.map((f) => f.name).toList(),
        'reason': log.result.reason,
        'validatedAt': log.result.validatedAt.toIso8601String(),
        'metadata': log.result.metadata,
      },
      'deviceInfo': log.deviceInfo,
      'detectionDetails': log.detectionDetails,
    };
    return encodeToJson(json);
  }

  /// Deserialize JSON string ke DetectionLog
  static DetectionLog deserializeDetectionLog(String jsonString) {
    final json = decodeFromJson(jsonString);
    return DetectionLog.fromJson(json);
  }

  /// Serialize list of DetectionLogs ke JSON string
  static String serializeDetectionLogs(List<DetectionLog> logs) {
    final jsonList = logs
        .map((log) => {
              'id': log.id,
              'userId': log.userId,
              'timestamp': log.timestamp.toIso8601String(),
              'location': log.location.toJson(),
              'result': {
                'isValid': log.result.isValid,
                'riskScore': log.result.riskScore,
                'flags': log.result.flags.map((f) => f.name).toList(),
                'reason': log.result.reason,
                'validatedAt': log.result.validatedAt.toIso8601String(),
                'metadata': log.result.metadata,
              },
              'deviceInfo': log.deviceInfo,
              'detectionDetails': log.detectionDetails,
            })
        .toList();

    return encodeToJson(jsonList);
  }

  /// Deserialize JSON string ke list of DetectionLogs
  static List<DetectionLog> deserializeDetectionLogs(String jsonString) {
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList
        .map((json) => DetectionLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Serialize DetectionConfig ke JSON string
  static String serializeDetectionConfig(DetectionConfig config) {
    return encodeToJson(config.toJson());
  }

  /// Deserialize JSON string ke DetectionConfig
  static DetectionConfig deserializeDetectionConfig(String jsonString) {
    final json = decodeFromJson(jsonString);
    return DetectionConfig.fromJson(json);
  }

  /// Validate JSON string format
  static bool isValidJson(String jsonString) {
    try {
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Pretty print JSON string
  static String prettyPrintJson(String jsonString) {
    try {
      final object = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(object);
    } catch (e) {
      return jsonString; // Return original if can't format
    }
  }

  /// Compress JSON by removing whitespace
  static String compressJson(String jsonString) {
    try {
      final object = jsonDecode(jsonString);
      return jsonEncode(object);
    } catch (e) {
      return jsonString; // Return original if can't compress
    }
  }

  /// Safe JSON parsing with default value
  static T safeParseJson<T>(
    String jsonString,
    T Function(Map<String, dynamic>) parser,
    T defaultValue,
  ) {
    try {
      final json = decodeFromJson(jsonString);
      return parser(json);
    } catch (e) {
      return defaultValue;
    }
  }
}
