import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  static const List<String> allowedRoles = ['admin', 'staff', 'supervisor', 'storage-staff'];

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: ApiConstants.headers(null),
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final userData = responseData['data'];
        final userRoles = List<String>.from(userData['user']['roles']);

        final hasAllowedRole =
            userRoles.any((role) => allowedRoles.contains(role));

        if (hasAllowedRole) {
          await _saveUserData(userData);
          return {'success': true, 'message': 'Login successful'};
        } else {
          return {
            'success': false,
            'message': 'Anda tidak memiliki akses ke aplikasi ini'
          };
        }
      }

      return {
        'success': false,
        'message': responseData['message'] ?? 'Login gagal'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // Simpan token
    final token = data['access_token'];
    if (token != null) {
      await prefs.setString('token', token.toString());
      await prefs.setString('token_type', data['token_type'] ?? 'Bearer');
      print('Token tersimpan: $token');
    }

    // Simpan data user
    final user = data['user'];
    if (user != null) {
      await prefs.setString('user', json.encode(user));
      print('User data tersimpan: ${json.encode(user)}');
    } else {
      print('Data user tidak ditemukan dalam response');
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

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenType = prefs.getString('token_type');
    final accessToken = prefs.getString('token');

    if (tokenType != null && accessToken != null) {
      return '$tokenType $accessToken';
    }

    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('token_type');
    await prefs.remove('user');
    await prefs.remove(AppConstants.loginDataKey);
  }
}
