import '../models/store_model.dart';
import '../utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

class StoreService {
  final AuthService _authService = AuthService();

  static const String baseUrl = ApiConstants.baseUrl;

  Future<List<StoreModel>> getStores() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Token not found');
      }
      final response = await http.get(
        Uri.parse(ApiConstants.stores),
        headers: ApiConstants.headers(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          final List<dynamic> storesData = data['data'];
          return storesData.map((store) => StoreModel.fromJson(store)).toList();
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
}
