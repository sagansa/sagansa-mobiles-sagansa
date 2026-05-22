import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;  // Add this import
import '../services/auth_service.dart';
import '../services/leave_service.dart';
import '../services/presence_service.dart';
import '../utils/constants.dart';

class HomeController {
  final BuildContext context;
  Map<String, String>? _cachedUserInfo;

  HomeController(this.context);

  Future<Map<String, String>> loadUserInfo() async {
    if (_cachedUserInfo != null) {
      return _cachedUserInfo!;
    }

    final prefs = await SharedPreferences.getInstance();
    final loginDataString = prefs.getString(AppConstants.loginDataKey);

    if (loginDataString != null) {
      final loginData = json.decode(loginDataString);
      final userData = loginData['data']['user'];

      _cachedUserInfo = {
        'userName': userData['name'] ?? '',
        'companyName': userData['company']?['name'] ?? 'SAGANSA',
      };

      return _cachedUserInfo!;
    }
    throw Exception('User data not found');
  }

  void clearCache() {
    _cachedUserInfo = null;
  }

  Future<Map<String, dynamic>> loadPresenceData() async {
    try {
      final data = await PresenceService.getUserPresence();
      developer.log('Raw presence data from service: ${json.encode(data)}', name: 'HomeController');
      return data;
    } catch (e) {
      developer.log('Error in loadPresenceData: $e', name: 'HomeController');
      throw Exception('Gagal memuat data: $e');
    }
  }

  Future<bool> checkActiveLeave() async {
    try {
      final leaveService = LeaveService();
      final leaves = await leaveService.getLeaves();
      final now = DateTime.now();

      return leaves.any((leave) =>
          leave.status == AppConstants.leaveStatusApproved &&
          leave.fromDate.isBefore(now) &&
          leave.untilDate.isAfter(now));
    } catch (e) {
      print('Error checking active leave: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final authService = AuthService();
      await authService.logout();
    } catch (e) {
      throw Exception(e.toString());
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
