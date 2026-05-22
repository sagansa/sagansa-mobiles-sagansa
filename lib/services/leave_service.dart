import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/leave_model.dart';
import '../utils/constants.dart';

class LeaveService {
  Future<List<LeaveModel>> getLeaves() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiConstants.leaves),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> leavesJson = data['data'];
      return leavesJson.map((json) => LeaveModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load leaves');
    }
  }

  Future<bool> submitLeave({
    required int reason,
    required DateTime fromDate,
    required DateTime untilDate,
    String? notes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse(ApiConstants.leaves),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'reason': reason,
        'from_date': fromDate.toIso8601String(),
        'until_date': untilDate.toIso8601String(),
        'notes': notes,
      }),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Failed to submit leave');
    }
  }

  Future<void> updateLeave(
    int leaveId,
    String reason,
    DateTime fromDate,
    DateTime untilDate,
    String notes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('${ApiConstants.leaves}/$leaveId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'reason': int.parse(reason),
        'from_date': fromDate.toIso8601String(),
        'until_date': untilDate.toIso8601String(),
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['success'] == false) {
        throw Exception(responseData['message'] ?? 'Gagal mengupdate cuti');
      }
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Gagal mengupdate cuti');
    }
  }
}
