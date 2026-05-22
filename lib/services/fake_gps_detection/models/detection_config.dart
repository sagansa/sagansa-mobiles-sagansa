/// Konfigurasi untuk sistem deteksi GPS palsu
class DetectionConfig {
  final double
      riskThreshold; // 0.0 - 1.0, threshold untuk menentukan lokasi valid
  final bool enableMockDetection;
  final bool enableSignalAnalysis;
  final bool enableSensorValidation;
  final bool enableNetworkValidation;
  final bool enableBehaviorAnalysis;
  final Duration validationTimeout;
  final int maxHistorySize;
  final double minAccuracyThreshold; // dalam meter
  final double maxSpeedThreshold; // dalam m/s

  const DetectionConfig({
    this.riskThreshold = 0.5,
    this.enableMockDetection = true,
    this.enableSignalAnalysis = true,
    this.enableSensorValidation = true,
    this.enableNetworkValidation = false,
    this.enableBehaviorAnalysis = false,
    this.validationTimeout = const Duration(seconds: 5),
    this.maxHistorySize = 50,
    this.minAccuracyThreshold = 100.0,
    this.maxSpeedThreshold = 50.0, // ~180 km/h
  });

  factory DetectionConfig.fromJson(Map<String, dynamic> json) {
    return DetectionConfig(
      riskThreshold: json['riskThreshold']?.toDouble() ?? 0.5,
      enableMockDetection: json['enableMockDetection'] ?? true,
      enableSignalAnalysis: json['enableSignalAnalysis'] ?? true,
      enableSensorValidation: json['enableSensorValidation'] ?? true,
      enableNetworkValidation: json['enableNetworkValidation'] ?? false,
      enableBehaviorAnalysis: json['enableBehaviorAnalysis'] ?? false,
      validationTimeout: Duration(
        milliseconds: json['validationTimeoutMs'] ?? 5000,
      ),
      maxHistorySize: json['maxHistorySize'] ?? 50,
      minAccuracyThreshold: json['minAccuracyThreshold']?.toDouble() ?? 100.0,
      maxSpeedThreshold: json['maxSpeedThreshold']?.toDouble() ?? 50.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'riskThreshold': riskThreshold,
      'enableMockDetection': enableMockDetection,
      'enableSignalAnalysis': enableSignalAnalysis,
      'enableSensorValidation': enableSensorValidation,
      'enableNetworkValidation': enableNetworkValidation,
      'enableBehaviorAnalysis': enableBehaviorAnalysis,
      'validationTimeoutMs': validationTimeout.inMilliseconds,
      'maxHistorySize': maxHistorySize,
      'minAccuracyThreshold': minAccuracyThreshold,
      'maxSpeedThreshold': maxSpeedThreshold,
    };
  }

  DetectionConfig copyWith({
    double? riskThreshold,
    bool? enableMockDetection,
    bool? enableSignalAnalysis,
    bool? enableSensorValidation,
    bool? enableNetworkValidation,
    bool? enableBehaviorAnalysis,
    Duration? validationTimeout,
    int? maxHistorySize,
    double? minAccuracyThreshold,
    double? maxSpeedThreshold,
  }) {
    return DetectionConfig(
      riskThreshold: riskThreshold ?? this.riskThreshold,
      enableMockDetection: enableMockDetection ?? this.enableMockDetection,
      enableSignalAnalysis: enableSignalAnalysis ?? this.enableSignalAnalysis,
      enableSensorValidation:
          enableSensorValidation ?? this.enableSensorValidation,
      enableNetworkValidation:
          enableNetworkValidation ?? this.enableNetworkValidation,
      enableBehaviorAnalysis:
          enableBehaviorAnalysis ?? this.enableBehaviorAnalysis,
      validationTimeout: validationTimeout ?? this.validationTimeout,
      maxHistorySize: maxHistorySize ?? this.maxHistorySize,
      minAccuracyThreshold: minAccuracyThreshold ?? this.minAccuracyThreshold,
      maxSpeedThreshold: maxSpeedThreshold ?? this.maxSpeedThreshold,
    );
  }

  @override
  String toString() {
    return 'DetectionConfig(threshold: $riskThreshold, timeout: ${validationTimeout.inSeconds}s)';
  }
}
