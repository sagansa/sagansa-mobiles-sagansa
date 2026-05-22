import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';

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
    print('AuthProvider constructor called');
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      print('Loading token...');
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token') ?? '';
      print('Token loaded: ${_token.isNotEmpty ? 'exists' : 'empty'}');

      // Load user data if token exists
      if (_token.isNotEmpty) {
        final userDataString = prefs.getString('user');
        if (userDataString != null) {
          try {
            _userData = json.decode(userDataString);
            print('User data loaded successfully');
          } catch (e) {
            print('Error parsing user data: $e');
            _userData = null;
          }
        }
      }

      _authState = AuthState.idle;
      notifyListeners();
      print('Token loading completed');
    } catch (e) {
      print('Error loading token: $e');
      _token = '';
      _userData = null;
      _authState = AuthState.error;
      _errorMessage = 'Failed to load authentication data';
      notifyListeners();
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

      debugPrint('AuthProvider: Login result status: ${result['status']}');

      if (result['status'] == 'error') {
        _authState = AuthState.error;
        _errorMessage = result['message'] ?? 'Login gagal';
        _setLoading(false);
        notifyListeners();
        debugPrint('AuthProvider: Login failed: $_errorMessage');
        return false;
      }

      // Validate response data
      if (result['data'] == null ||
          result['data']['access_token'] == null ||
          result['data']['user'] == null) {
        _authState = AuthState.error;
        _errorMessage = 'Response data tidak valid';
        _setLoading(false);
        notifyListeners();
        debugPrint('AuthProvider: Invalid response data');
        return false;
      }

      // Success
      _token = result['data']['access_token'];
      _userData = result['data']['user'];
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
      await _authService.logout();
      _token = '';
      _userData = null;
      _authState = AuthState.idle;
      _errorMessage = '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal melakukan logout';
      _setLoading(false);
      notifyListeners();
      return false;
    }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
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
}
