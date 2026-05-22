import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/services/fake_gps_detection/models/models.dart';
import 'package:sagansa/services/fake_gps_detection/services/audit_service.dart';
import 'package:sagansa/services/fake_gps_detection/utils/json_utils.dart';

void main() {
  group('AuditService Tests', () {
    late AuditService auditService;

    setUp(() {
      auditService = AuditService();
    });

    test('should create detection log with proper data', () async {
      // Arrange
      final locationData = LocationData(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracy: 10.0,
        altitude: 100.0,
        speed: 0.0,
        bearing: 0.0,
        timestamp: DateTime.now(),
        provider: 'gps',
      );

      final validationResult = ValidationResult(
        isValid: true,
        riskScore: 0.1,
        flags: [],
        reason: 'Location validation passed',
        validatedAt: DateTime.now(),
      );

      // Act & Assert - should not throw
      expect(
        () async => await auditService.logDetection(
          userId: 'test_user_123',
          location: locationData,
          result: validationResult,
          additionalDetails: {'test': 'data'},
        ),
        returnsNormally,
      );
    });

    test('should handle invalid detection log', () async {
      // Arrange
      final locationData = LocationData(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracy: 10.0,
        altitude: 100.0,
        speed: 0.0,
        bearing: 0.0,
        timestamp: DateTime.now(),
        provider: 'mock',
      );

      final validationResult = ValidationResult(
        isValid: false,
        riskScore: 0.8,
        flags: [DetectionFlag.mockLocationEnabled],
        reason: 'Mock location detected',
        validatedAt: DateTime.now(),
      );

      // Act & Assert - should not throw
      expect(
        () async => await auditService.logDetection(
          userId: 'test_user_123',
          location: locationData,
          result: validationResult,
        ),
        returnsNormally,
      );
    });
  });

  group('JsonUtils Tests', () {
    test('should serialize and deserialize LocationData correctly', () {
      // Arrange
      final originalLocation = LocationData(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracy: 10.0,
        altitude: 100.0,
        speed: 5.0,
        bearing: 90.0,
        timestamp: DateTime.now(),
        provider: 'gps',
        extras: {'test': 'value'},
      );

      // Act
      final serialized = JsonUtils.serializeLocationData(originalLocation);
      final deserialized = JsonUtils.deserializeLocationData(serialized);

      // Assert
      expect(deserialized.latitude, equals(originalLocation.latitude));
      expect(deserialized.longitude, equals(originalLocation.longitude));
      expect(deserialized.accuracy, equals(originalLocation.accuracy));
      expect(deserialized.provider, equals(originalLocation.provider));
    });

    test('should serialize and deserialize ValidationResult correctly', () {
      // Arrange
      final originalResult = ValidationResult(
        isValid: false,
        riskScore: 0.7,
        flags: [
          DetectionFlag.mockLocationEnabled,
          DetectionFlag.signalInconsistent
        ],
        reason: 'Multiple issues detected',
        validatedAt: DateTime.now(),
        metadata: {'detector': 'MockLocationDetector'},
      );

      // Act
      final serialized = JsonUtils.serializeValidationResult(originalResult);
      final deserialized = JsonUtils.deserializeValidationResult(serialized);

      // Assert
      expect(deserialized.isValid, equals(originalResult.isValid));
      expect(deserialized.riskScore, equals(originalResult.riskScore));
      expect(deserialized.flags.length, equals(originalResult.flags.length));
      expect(deserialized.reason, equals(originalResult.reason));
    });

    test('should handle invalid JSON gracefully', () {
      // Arrange
      const invalidJson = 'invalid json string';

      // Act & Assert
      expect(
        () => JsonUtils.deserializeLocationData(invalidJson),
        throwsException,
      );

      expect(
        () => JsonUtils.deserializeValidationResult(invalidJson),
        throwsException,
      );
    });

    test('should validate JSON format correctly', () {
      // Arrange
      const validJson = '{"key": "value"}';
      const invalidJson = 'invalid json';

      // Act & Assert
      expect(JsonUtils.isValidJson(validJson), isTrue);
      expect(JsonUtils.isValidJson(invalidJson), isFalse);
    });
  });

  group('DetectionLog Tests', () {
    test('should create DetectionLog with generated ID', () {
      // Arrange
      final locationData = LocationData(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracy: 10.0,
        altitude: 100.0,
        speed: 0.0,
        bearing: 0.0,
        timestamp: DateTime.now(),
        provider: 'gps',
      );

      final validationResult = ValidationResult(
        isValid: true,
        riskScore: 0.1,
        flags: [],
        reason: 'Valid location',
        validatedAt: DateTime.now(),
      );

      // Act
      final log = DetectionLog.create(
        userId: 'test_user',
        location: locationData,
        result: validationResult,
        deviceInfo: 'Test Device',
      );

      // Assert
      expect(log.id, isNotEmpty);
      expect(log.id, startsWith('det_'));
      expect(log.userId, equals('test_user'));
      expect(log.deviceInfo, equals('Test Device'));
    });

    test('should serialize and deserialize DetectionLog correctly', () {
      // Arrange
      final locationData = LocationData(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracy: 10.0,
        altitude: 100.0,
        speed: 0.0,
        bearing: 0.0,
        timestamp: DateTime.now(),
        provider: 'gps',
      );

      final validationResult = ValidationResult(
        isValid: false,
        riskScore: 0.6,
        flags: [DetectionFlag.mockLocationEnabled],
        reason: 'Mock location detected',
        validatedAt: DateTime.now(),
      );

      final originalLog = DetectionLog.create(
        userId: 'test_user',
        location: locationData,
        result: validationResult,
        deviceInfo: 'Test Device',
        detectionDetails: {'method': 'test'},
      );

      // Act
      final json = originalLog.toJson();
      final deserializedLog = DetectionLog.fromJson(json);

      // Assert
      expect(deserializedLog.id, equals(originalLog.id));
      expect(deserializedLog.userId, equals(originalLog.userId));
      expect(
          deserializedLog.result.isValid, equals(originalLog.result.isValid));
      expect(deserializedLog.result.riskScore,
          equals(originalLog.result.riskScore));
    });
  });
}
