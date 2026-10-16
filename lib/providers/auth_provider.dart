import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/leave_service.dart';
import '../services/token_store.dart';
import '../services/widget_bridge.dart';
import '../utils/constants.dart';

enum AuthState { idle, loading, success, error }

class AuthProvider with ChangeNotifier {
  String _token = '';
  Map<String, dynamic>? _userData;
  AuthState _authState = AuthState.idle;
  String _errorMessage = '';
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  // Getters
  String get token => _token;
  Map<String, dynamic>? get userData => _userData;
  AuthState get authState => _authState;
  String get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token.isNotEmpty;

  AuthProvider() {
    debugPrint('AuthProvider constructor called');
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      debugPrint('Loading token...');
      _token = await TokenStore.instance.readToken() ?? '';
      debugPrint('Token loaded: ${_token.isNotEmpty ? 'exists' : 'empty'}');

      // Load user data if token exists
      if (_token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user');
        if (userDataString != null) {
          try {
            _userData = json.decode(userDataString);
            debugPrint('User data loaded successfully');
          } catch (e) {
            debugPrint('Error parsing user data: $e');
            _userData = null;
          }
        }
      }

      _authState = AuthState.idle;
      notifyListeners();
      debugPrint('Token loading completed');
      // Sinkron token ke widget iOS (App Group) — fire and forget.
      unawaited(WidgetBridge.syncAuth(token: _token, isAdmin: isAdmin));
    } catch (e) {
      debugPrint('Error loading token: $e');
      _token = '';
      _userData = null;
      _authState = AuthState.error;
      _errorMessage = 'Failed to load authentication data';
      notifyListeners();
      unawaited(WidgetBridge.syncAuth(token: null, isAdmin: false));
    }
  }

  Future<bool> login(String email, String password) async {
    // Validate input
    if (email.trim().isEmpty || password.isEmpty) {
      _authState = AuthState.error;
      _errorMessage = 'Email dan password tidak boleh kosong';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _authState = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      debugPrint('AuthProvider: Attempting login for email: $email');
      final result = await _authService.login(email, password);

      debugPrint('AuthProvider: Login result status: ${result['success']}');

      if (result['success'] != true) {
        _authState = AuthState.error;
        _errorMessage = result['message'] ?? 'Login gagal';
        _setLoading(false);
        notifyListeners();
        debugPrint('AuthProvider: Login failed: $_errorMessage');
        return false;
      }

      // Success - reload token and user data from SharedPreferences
      await _loadToken();
      _authState = AuthState.success;
      _setLoading(false);
      notifyListeners();
      debugPrint(
          'AuthProvider: Login successful for user: ${_userData?['name']}');
      return true;
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage =
          'Terjadi kesalahan saat login. Periksa koneksi internet Anda.';
      _setLoading(false);
      notifyListeners();
      debugPrint('AuthProvider: Login exception: $e');
      return false;
    }
  }

  Future<bool> logout() async {
    _setLoading(true);
    notifyListeners();

    try {
      // Batasi waktu logout (API + deregister FCM/periodic task). Jika layanan
      // lambat/tidak merespons, tetap lanjut membersihkan prefs & kembali ke
      // login — sebelumnya request tanpa timeout bisa menggantung dan membuat
      // user tidak pernah kembali ke menu login.
      await _authService.logout().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('AuthProvider: Error during _authService.logout(): $e');
    } finally {
      _token = '';
      _userData = null;
      _authState = AuthState.idle;
      _errorMessage = '';

      try {
        await TokenStore.instance.clear();
      } catch (e) {
        debugPrint('AuthProvider: TokenStore.clear failed: $e');
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user');
        await prefs.remove(AppConstants.loginDataKey);
      } catch (e) {
        debugPrint('AuthProvider: Error clearing prefs in finally: $e');
      }

      unawaited(WidgetBridge.syncAuth(token: null, isAdmin: false));

      _setLoading(false);
      notifyListeners();
    }
    return true;
  }

  Future<void> refreshAuth() async {
    _setLoading(true);
    notifyListeners();

    // Simulate refresh - in real app, you'd call an API to refresh token
    await Future.delayed(const Duration(seconds: 1));

    _setLoading(false);
    notifyListeners();
  }

  Future<void> updateToken(String newToken) async {
    _token = newToken;
    await TokenStore.instance.writeToken(newToken);
    unawaited(WidgetBridge.syncAuth(token: newToken, isAdmin: isAdmin));
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  void clearError() {
    _errorMessage = '';
    _authState = AuthState.idle;
    notifyListeners();
  }

  /// Reinitialize the auth provider (retry initialization)
  Future<void> reinitialize() async {
    if (kDebugMode) {
      debugPrint('AuthProvider: Reinitializing...');
    }

    _authState = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      await _loadToken();
      if (kDebugMode) {
        debugPrint('AuthProvider: Reinitialization complete');
      }
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = 'Failed to reinitialize: $e';
      notifyListeners();
      if (kDebugMode) {
        debugPrint('AuthProvider: Reinitialization failed: $e');
      }
    }
  }

  /// Check if the provider has been initialized
  bool get hasInitialized => _authState != AuthState.loading;

  /// Check if the current user has any of the specified roles
  bool hasAnyRole(List<String> rolesToCheck) {
    if (_userData == null) return false;
    final userRoles = List<String>.from(_userData!['roles'] ?? []);
    return userRoles.any((role) => rolesToCheck.contains(role));
  }

  /// Roles user saat ini (untuk gating UI).
  List<String> get roles {
    if (_userData == null) return const [];
    return List<String>.from(_userData!['roles'] ?? []);
  }

  /// Convenience getters untuk role-based UI gating.
  bool get isAdmin => hasAnyRole(const ['admin', 'super_admin']);
  bool get isStorageStaff => roles.contains('storage-staff');

  /// Mode sales-only: punya role `sales` dan TIDAK punya role staf aktif
  /// (admin, super_admin, staff, supervisor, storage-staff). `former-employee`
  /// tidak dianggap role staf, jadi `sales + former-employee` masuk mode ini.
  bool get isSalesOnly =>
      roles.contains('sales') &&
      !hasAnyRole(const [
        'admin',
        'super_admin',
        'staff',
        'supervisor',
        'storage-staff',
      ]);

  /// Berjual = ber-role `sales` — termasuk `sales + former-employee`
  /// (sales eksternal yang tetap menjual, keputusan 2026-10-16).
  bool get canSell => roles.contains('sales');

  // --- Home data (absorbed from HomeController) ---

  Map<String, String>? _cachedUserInfo;

  String get userName => _cachedUserInfo?['userName'] ?? '';
  String get companyName => _cachedUserInfo?['companyName'] ?? 'SAGANSA';

  bool _hasActiveLeave = false;
  bool get hasActiveLeave => _hasActiveLeave;

  Future<void> loadUserInfo() async {
    if (_cachedUserInfo != null) return;

    final prefs = await SharedPreferences.getInstance();
    final loginDataString = prefs.getString(AppConstants.loginDataKey);

    if (loginDataString != null) {
      final loginData = json.decode(loginDataString);
      final userData = loginData['data']['user'];

      _cachedUserInfo = {
        'userName': userData['name'] ?? '',
        'companyName': userData['company']?['name'] ?? 'SAGANSA',
      };

      notifyListeners();
    }
  }

  Future<void> checkActiveLeave() async {
    try {
      final leaveService = LeaveService();
      final leaves = await leaveService.getLeaves();
      final now = DateTime.now();

      _hasActiveLeave = leaves.any((leave) =>
          leave.status == AppConstants.leaveStatusApproved &&
          leave.fromDate.isBefore(now) &&
          leave.untilDate.isAfter(now));

      notifyListeners();
    } catch (e) {
      _hasActiveLeave = false;
    }
  }

  Map<String, String> splitDateTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString);
    return {
      'date':
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}',
      'time':
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
    };
  }
}
