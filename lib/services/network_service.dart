import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class NetworkService {
  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      // Try multiple DNS lookups to be more reliable
      final futures = [
        InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5)),
        InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(seconds: 5)),
        InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 5)),
      ];

      // If any of the lookups succeed, we have internet
      for (final future in futures) {
        try {
          final result = await future;
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            debugPrint('NetworkService: Internet connection confirmed');
            return true;
          }
        } catch (e) {
          debugPrint('NetworkService: DNS lookup failed: $e');
          continue;
        }
      }

      debugPrint('NetworkService: All DNS lookups failed');
      return false;
    } catch (e) {
      debugPrint('NetworkService: Error checking internet: $e');
      return false;
    }
  }

  /// Check if API server is reachable
  static Future<bool> isApiServerReachable() async {
    try {
      // First try with domain name
      final response = await http.head(
        Uri.parse('${ApiConstants.baseUrl}/login'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode < 500; // Any response except server error
    } catch (e) {
      debugPrint('NetworkService: API server not reachable via domain: $e');

      // Try with IP address as fallback
      try {
        final response = await http.head(
          Uri.parse('${ApiConstants.fallbackBaseUrl}/login'),
          headers: {
            'Accept': 'application/json',
            'Host': 'api.sagansa.id', // Important: keep original host header
          },
        ).timeout(const Duration(seconds: 10));

        return response.statusCode < 500;
      } catch (fallbackError) {
        debugPrint(
            'NetworkService: API server not reachable via IP: $fallbackError');
        return false;
      }
    }
  }

  /// Get network status with detailed information
  static Future<NetworkStatus> getNetworkStatus() async {
    debugPrint('NetworkService: Starting network status check...');

    final hasInternet = await hasInternetConnection();
    debugPrint('NetworkService: Internet check result: $hasInternet');

    if (!hasInternet) {
      return NetworkStatus(
        isConnected: false,
        canReachApi: false,
        message: 'Tidak ada koneksi internet',
      );
    }

    final canReachApi = await isApiServerReachable();
    debugPrint('NetworkService: API server check result: $canReachApi');

    if (!canReachApi) {
      return NetworkStatus(
        isConnected: true,
        canReachApi: false,
        message: 'Server API tidak dapat dijangkau',
      );
    }

    return NetworkStatus(
      isConnected: true,
      canReachApi: true,
      message: 'Koneksi normal',
    );
  }

  /// Try to resolve DNS for API domain
  static Future<String?> resolveApiDomain() async {
    try {
      final result = await InternetAddress.lookup('api.sagansa.id');
      if (result.isNotEmpty) {
        return result.first.address;
      }
      return null;
    } catch (e) {
      debugPrint('NetworkService: DNS resolution failed: $e');
      return null;
    }
  }
}

class NetworkStatus {
  final bool isConnected;
  final bool canReachApi;
  final String message;

  NetworkStatus({
    required this.isConnected,
    required this.canReachApi,
    required this.message,
  });

  bool get isFullyConnected => isConnected && canReachApi;
}
