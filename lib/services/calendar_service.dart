import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/calendar_model.dart';
import '../utils/constants.dart';

class CalendarService {
  final String? token;

  CalendarService({this.token});

  Future<CalendarModel> getCalendarData() async {
    try {
      debugPrint('Fetching calendar data from: ${ApiConstants.calendar}');
      debugPrint(
          'Using token: ${token != null ? 'Token available' : 'No token'}');

      final response = await http.get(
        Uri.parse(ApiConstants.calendar),
        headers: ApiConstants.headers(token),
      );

      debugPrint('Calendar API response status: ${response.statusCode}');
      debugPrint('Calendar API response body: ${response.body}');

      if (response.statusCode == AppConstants.statusSuccess) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return CalendarModel.fromJson(jsonResponse);
      } else if (response.statusCode == AppConstants.statusUnauthorized) {
        throw Exception('Token tidak valid atau sudah expired');
      } else {
        throw Exception(
            'Gagal mengambil data kalender (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Calendar service error: $e');
      throw Exception('Error: $e');
    }
  }
}
