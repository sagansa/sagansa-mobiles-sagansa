import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store_model.dart';
import '../models/shift_store_model.dart';
import 'dart:io';
import '../utils/constants.dart';
import 'dart:developer' as developer;

class PresenceService {
  static const String tokenKey = 'token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    print('Token yang diambil: $token');
    return token;
  }

  static Future<List<Store>> getStores() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.stores),
        headers: ApiConstants.headers(await getToken()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          final List<dynamic> storesData = data['data'];
          return storesData.map((store) => Store.fromJson(store)).toList();
        } else {
          throw Exception('Data stores tidak ditemukan');
        }
      } else {
        throw Exception('Gagal memuat data stores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error dalam getStores: $e');
      throw Exception('Gagal memuat data stores: $e');
    }
  }

  static Future<List<ShiftStore>> getShiftStores() async {
    print('Memulai getShiftStores()');
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http
          .get(
            Uri.parse(ApiConstants.shiftStores),
            headers: ApiConstants.headers(token),
          )
          .timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if ((responseData['success'] == true || responseData['status'] == 'success') &&
            responseData['data'] is List) {
          final List<dynamic> shiftStoresData = responseData['data'];
          return shiftStoresData
              .map((json) => ShiftStore.fromJson(json))
              .toList();
        } else {
          throw Exception('Format respons tidak sesuai');
        }
      } else {
        throw Exception('Gagal memuat data shift: ${response.statusCode}');
      }
    } catch (e) {
      print('Error dalam getShiftStores: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadImage(
    File imageFile,
    bool isCheckIn,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    final endpoint = isCheckIn ? '/check-in' : '/check-out';
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    try {
      var request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiConstants.headers(token))
        ..fields
            .addAll(data.map((key, value) => MapEntry(key, value.toString())))
        ..files.add(await http.MultipartFile.fromPath(
          isCheckIn ? 'image_in' : 'image_out',
          imageFile.path,
        ));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData); // Langsung return decoded response
    } catch (e) {
      throw Exception('Gagal mengirim data presensi');
    }
  }

  static Future<void> submitPresence(
    Map<String, dynamic> data,
    bool isCheckIn,
  ) async {
    try {
      final token = await getToken();
      final endpoint = isCheckIn ? '/check-in' : '/check-out';
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

      final response = await http.post(
        uri,
        headers: ApiConstants.headers(token),
        body: data,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception('Gagal melakukan presensi: ${responseData['message']}');
      }
    } catch (e) {
      throw Exception('Error saat submit presensi: $e');
    }
  }

  static Future<Map<String, dynamic>> getUserPresence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      
      final response = await http.get(
        Uri.parse(ApiConstants.userPresence),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      developer.log('User Presence API Raw Response: ${response.body}', name: 'PresenceService');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load presence data (status: ${response.statusCode}, body: ${response.body})');
      }
    } catch (e) {
      developer.log('Error in getUserPresence', error: e, name: 'PresenceService');
      throw Exception('Failed to load presence data: $e');
    }
  }

  static Future<Map<String, dynamic>> getSalesOrders({int page = 1, int perPage = 10}) async {
    try {
      final token = await getToken();
      final uri = Uri.parse('${ApiConstants.searchSalesOrder}?page=$page&per_page=$perPage');
      final response = await http.get(
        uri,
        headers: ApiConstants.headers(token),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Gagal memuat daftar order.');
      }
    } catch (e) {
      throw Exception('Error saat memuat daftar order: $e');
    }
  }

  static Future<Map<String, dynamic>> searchSalesOrder(String receiptNo) async {
    try {
      final token = await getToken();
      final uri = Uri.parse('${ApiConstants.searchSalesOrder}?receipt_no=$receiptNo');
      final response = await http.get(
        uri,
        headers: ApiConstants.headers(token),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Gagal mencari data resi.');
      }
    } catch (e) {
      throw Exception('Error saat mencari resi: $e');
    }
  }

  static Future<Map<String, dynamic>> updateDeliveryStatus({
    required String receiptNo,
    required File imageFile,
    String? receivedBy,
  }) async {
    final token = await getToken();
    final uri = Uri.parse(ApiConstants.updateDeliveryStatus);

    try {
      var request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiConstants.headers(token))
        ..fields.addAll({
          'receipt_no': receiptNo,
          if (receivedBy != null && receivedBy.isNotEmpty) 'received_by': receivedBy,
        })
        ..files.add(await http.MultipartFile.fromPath(
          'image_delivery',
          imageFile.path,
        ));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final decodedData = json.decode(responseData);
      
      if (response.statusCode == 200) {
        return decodedData;
      } else {
        throw Exception(decodedData['message'] ?? 'Gagal memperbarui status pengiriman.');
      }
    } catch (e) {
      throw Exception('Error saat memperbarui pengiriman: $e');
    }
  }

  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'model': await _getDeviceModel(),
      // ... informasi device lainnya
    };
  }

  static Future<String> _getDeviceModel() async {
    // Implementasikan untuk mendapatkan model device
    return '';
  }
}
