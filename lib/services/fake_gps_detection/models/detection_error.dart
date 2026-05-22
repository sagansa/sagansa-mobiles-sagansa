/// Enum untuk berbagai jenis error yang dapat terjadi selama deteksi
enum DetectionError {
  locationServiceDisabled,
  permissionDenied,
  networkTimeout,
  sensorUnavailable,
  platformNotSupported,
  configurationError,
  validationTimeout,
  unknownError,
}

/// Exception yang dilempar saat terjadi error dalam proses deteksi
class DetectionException implements Exception {
  final DetectionError errorType;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const DetectionException({
    required this.errorType,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  factory DetectionException.locationServiceDisabled() {
    return const DetectionException(
      errorType: DetectionError.locationServiceDisabled,
      message:
          'Location services are disabled. Please enable location services to continue.',
    );
  }

  factory DetectionException.permissionDenied() {
    return const DetectionException(
      errorType: DetectionError.permissionDenied,
      message:
          'Location permission denied. Please grant location permission to use this feature.',
    );
  }

  factory DetectionException.networkTimeout() {
    return const DetectionException(
      errorType: DetectionError.networkTimeout,
      message:
          'Network timeout occurred during validation. Please check your internet connection.',
    );
  }

  factory DetectionException.sensorUnavailable() {
    return const DetectionException(
      errorType: DetectionError.sensorUnavailable,
      message: 'Required sensors are not available on this device.',
    );
  }

  factory DetectionException.platformNotSupported() {
    return const DetectionException(
      errorType: DetectionError.platformNotSupported,
      message:
          'This detection method is not supported on the current platform.',
    );
  }

  factory DetectionException.configurationError(String details) {
    return DetectionException(
      errorType: DetectionError.configurationError,
      message: 'Configuration error: $details',
    );
  }

  factory DetectionException.validationTimeout() {
    return const DetectionException(
      errorType: DetectionError.validationTimeout,
      message: 'Validation timeout. Please try again.',
    );
  }

  factory DetectionException.unknown(dynamic error, [StackTrace? stackTrace]) {
    return DetectionException(
      errorType: DetectionError.unknownError,
      message: 'An unknown error occurred: ${error.toString()}',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() {
    return 'DetectionException(${errorType.name}): $message';
  }
}
