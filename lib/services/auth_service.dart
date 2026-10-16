import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import 'api_client.dart';
import 'location_tracking_service.dart';
import 'token_store.dart';

class AuthService {
  static const List<String> allowedRoles = [
    'admin',
    'staff',
    'supervisor',
    'storage-staff',
    'sales',
  ];

  /// Role staf aktif — user yang memilikinya masuk "mode penuh".
  /// `former-employee` TIDAK termasuk di sini, jadi `sales + former-employee`
  /// otomatis masuk mode sales-only.
  static const List<String> staffRoles = [
    'admin',
    'super_admin',
    'staff',
    'supervisor',
    'storage-staff',
  ];

  /// Cek user tersimpan saat ini (prefs `user`) termasuk mode sales-only.
  /// Sales-only = punya role `sales` dan TIDAK punya role staf aktif.
  static Future<bool> isSalesOnlyUser() async {
    final roles = await _storedRoles();
    return roles.contains('sales') &&
        !roles.any((r) => staffRoles.contains(r));
  }

  /// Berjual = ber-role `sales` — termasuk `sales + former-employee`
  /// (sales eksternal yang tetap menjual, keputusan 2026-10-16).
  static Future<bool> canSell() async {
    final roles = await _storedRoles();
    return roles.contains('sales');
  }

  static Future<List<String>> _storedRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString == null) return const [];
    try {
      return List<String>.from(json.decode(userString)['roles'] ?? []);
    } catch (_) {
      return const [];
    }
  }

  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final userData = await _api.post('login', body: {
        'email': email,
        'password': password,
      });

      final userRoles = List<String>.from(userData['user']['roles']);

      final hasAllowedRole =
          userRoles.any((role) => allowedRoles.contains(role));

      if (hasAllowedRole) {
        await _saveUserData(userData);

        // Background location tracking dimatikan global (kill-switch di
        // LocationTrackingService). Untuk user sales-only, onLogin bahkan
        // tidak dipanggil — dia tidak punya fitur lokasi sama sekali.
        final isSalesOnly = userRoles.contains('sales') &&
            !userRoles.any((role) => staffRoles.contains(role));
        if (!isSalesOnly) {
          LocationTrackingService.instance.onLogin();
        }
        return {'success': true, 'message': 'Login successful'};
      } else {
        return {
          'success': false,
          'message': 'Anda tidak memiliki akses ke aplikasi ini'
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // Simpan token (secure storage, bukan prefs) untuk mencegah exposure
    // pada device rooted / backup forensic.
    final token = data['access_token'];
    if (token != null) {
      await TokenStore.instance.writeToken(
        token.toString(),
        tokenType: data['token_type']?.toString() ?? 'Bearer',
      );
      debugPrint('Token tersimpan di secure storage');
    }

    // Simpan data user
    final user = data['user'];
    if (user != null) {
      await prefs.setString('user', json.encode(user));
      debugPrint('User data tersimpan: ${json.encode(user)}');
    } else {
      debugPrint('Data user tidak ditemukan dalam response');
    }

    // Simpan full login data untuk HomeController
    await prefs.setString(
      AppConstants.loginDataKey,
      json.encode({
        'success': true,
        'data': data,
      }),
    );
  }

  Future<bool> hasRole(String roleToCheck) async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');

    if (userString != null) {
      final userData = json.decode(userString);
      final userRoles = List<String>.from(userData['roles']);
      return userRoles.contains(roleToCheck);
    }

    return false;
  }

  Future<bool> hasAnyAllowedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');

    if (userString != null) {
      final userData = json.decode(userString);
      final userRoles = List<String>.from(userData['roles']);
      return userRoles.any((role) => allowedRoles.contains(role));
    }

    return false;
  }

  Future<void> logout() async {
    // 1. Panggil API logout backend (opsional/silent jika gagal/offline)
    try {
      await _api.post('logout');
    } catch (e) {
      debugPrint('AuthService.logout: backend API logout failed ($e)');
    }

    // 2. Hentikan pelacakan & hapus FCM token device (silent jika gagal)
    try {
      await LocationTrackingService.instance.onLogout();
    } catch (e) {
      debugPrint('AuthService.logout: LocationTracking.onLogout failed ($e)');
    }

    // 3. Bersihkan token dari secure storage
    try {
      await TokenStore.instance.clear();
    } catch (e) {
      debugPrint('AuthService.logout: TokenStore.clear failed ($e)');
    }

    // 4. Bersihkan data non-token dari SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      await prefs.remove(AppConstants.loginDataKey);
    } catch (e) {
      debugPrint('AuthService.logout: clearing prefs failed ($e)');
    }
  }
}
