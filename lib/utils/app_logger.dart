import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

/// Helper logging terpusat yang release-aware.
///
/// - Level `debug` & `info`: no-op di release build (`kReleaseMode`).
/// - Level `warning` & `error`: selalu log (siap di-foward ke Crashlytics /
///   Sentry saat setup di masa depan).
///
/// **Penggunaan:**
/// ```dart
/// AppLogger.debug('User logged in: $userId');
/// AppLogger.error('Failed to fetch', error: e, stack: stack);
/// AppLogger.debug('Response: ${AppLogger.redact(json)}');
/// ```
class AppLogger {
  AppLogger._();

  /// Sensitive keys yang di-redact secara default oleh [redact].
  static const Set<String> defaultSensitiveKeys = {
    'token',
    'access_token',
    'password',
    'pin',
    'secret',
    'api_key',
    'apikey',
    'authorization',
  };

  /// Log level debug. No-op di release build.
  static void debug(String message, {Object? error, StackTrace? stack}) {
    if (kReleaseMode) return;
    // debugPrint: developer.log tidak muncul di adb logcat — cermin ke
    // logcat agar debugging perangkat/emulator bisa dari satu tempat.
    debugPrint('[sagansa] $message');
    if (error != null) {
      developer.log(message, error: error, stackTrace: stack, name: 'sagansa.debug');
    } else {
      developer.log(message, name: 'sagansa.debug');
    }
  }

  /// Log level info. No-op di release build.
  static void info(String message) {
    if (kReleaseMode) return;
    developer.log(message, name: 'sagansa.info');
  }

  /// Log level warning. Selalu aktif (juga di release).
  static void warning(String message, {Object? error}) {
    developer.log(
      message,
      error: error,
      name: 'sagansa.warning',
      level: 900,
    );
  }

  /// Log level error. Selalu aktif (juga di release).
  /// Wajib menyertakan [error] & [stack] untuk debugging yang baik.
  static void error(String message, {Object? error, StackTrace? stack}) {
    developer.log(
      message,
      error: error,
      stackTrace: stack,
      name: 'sagansa.error',
      level: 1000,
    );
  }

  /// Redact nilai key sensitif dari [data] sebelum di-log.
  ///
  /// Redaction bersifat **shallow** (hanya level pertama). Bila [data] punya
  /// nested map, field sensitif di dalamnya tidak akan ter-redact. Untuk
  /// redaction recursive, encode ke JSON lalu gunakan regex.
  ///
  /// [sensitiveKeys] case-insensitive (di-lowercase saat match).
  static Map<String, dynamic> redact(
    Map<String, dynamic> data, {
    Set<String> sensitiveKeys = defaultSensitiveKeys,
  }) {
    final lowered = sensitiveKeys.map((k) => k.toLowerCase()).toSet();
    return data.map((key, value) {
      if (lowered.contains(key.toLowerCase())) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });
  }

  /// Preview string dengan batas panjang — untuk log response body tanpa bocor.
  static String preview(String text, {int maxLength = 200}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}... (${text.length} bytes total)';
  }
}
