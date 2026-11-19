import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/shift_store_model.dart';
import '../models/store_model.dart';
import '../utils/constants.dart';
import 'api_client.dart';
import 'image_upload_service.dart';
import 'token_store.dart';

class PresenceService {
  final ApiClient _api = ApiClient();

  Future<List<Store>> getStores() async {
    try {
      final data = await _api.get('stores');
      return (data as List<dynamic>)
          .map((store) => Store.fromJson(store))
          .toList();
    } catch (e) {
      debugPrint('Error dalam getStores: $e');
      throw Exception('Gagal memuat data stores: $e');
    }
  }

  Future<List<ShiftStore>> getShiftStores() async {
    debugPrint('Memulai getShiftStores()');
    try {
      final data = await _api.get('shift-stores');
      debugPrint('Response data: $data');
      return (data as List<dynamic>)
          .map((json) => ShiftStore.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error dalam getShiftStores: $e');
      rethrow;
    }
  }

  /// Upload presence image via multipart POST.
  /// Kept on raw http because callers inspect `error_code` (READINESS_REQUIRED /
  /// HYGIENE_REQUIRED) which ApiClient._handleResponse strips away.
  Future<Map<String, dynamic>> uploadImage(
    File imageFile,
    bool isCheckIn,
    Map<String, dynamic> data,
  ) async {
    final endpoint = isCheckIn ? '/check-in' : '/check-out';
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(await _getAuthHeaders())
        ..fields
            .addAll(data.map((key, value) => MapEntry(key, value.toString())));

      final fieldName = isCheckIn ? 'image_in' : 'image_out';
      String? path;
      if (kIsWeb) {
        final bytes = await XFile(imageFile.path).readAsBytes();
        final ext = p.extension(imageFile.path).toLowerCase();
        final filename = isCheckIn ? 'image_in$ext' : 'image_out$ext';
        path = await ImageUploadService.uploadBytes(
          bytes,
          filename,
          directory: 'images/Presence',
        );
      } else {
        path = await ImageUploadService.upload(
          imageFile,
          directory: 'images/Presence',
        );
      }
      if (path == null) throw Exception('Gagal upload gambar presensi.');
      request.fields[fieldName] = path;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return json.decode(response.body);
    } catch (e) {
      developer.log('Error uploading presence image: $e',
          name: 'PresenceService');
      throw Exception('Gagal mengirim data presensi');
    }
  }

  Future<void> submitPresence(
    Map<String, dynamic> data,
    bool isCheckIn,
  ) async {
    try {
      final endpoint = isCheckIn ? '/check-in' : '/check-out';
      await _api.post(endpoint, body: data);
    } catch (e) {
      throw Exception('Error saat submit presensi: $e');
    }
  }

  // ===========================================================================
  // Admin manual presence management (CRUD).
  // Backend: AdminPresenceController at admin/presences.
  // Authorization: hanya role `admin`.
  // ===========================================================================

  /// Buat presensi manual untuk karyawan (admin).
  ///
  /// [data] harus berisi: created_by_id, store_id, shift_store_id, check_in,
  /// latitude_in, longitude_in, status. Optional: check_out, latitude_out,
  /// longitude_out.
  Future<Map<String, dynamic>> createPresenceManual(
      Map<String, dynamic> data) async {
    try {
      final result = await _api.post('admin/presences', body: data);
      return result is Map<String, dynamic>
          ? result
          : <String, dynamic>{};
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update presensi manual (admin).
  Future<Map<String, dynamic>> updatePresenceManual(
      int id, Map<String, dynamic> data) async {
    try {
      final result = await _api.put('admin/presences/$id', body: data);
      return result is Map<String, dynamic>
          ? result
          : <String, dynamic>{};
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Hapus presensi (admin).
  Future<void> deletePresence(int id) async {
    try {
      await _api.delete('admin/presences/$id');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Get all employees' presence data for today (admin only).
  /// Returns record (presences, summary) where summary contains
  /// late_count, on_time_count, total_count from backend.
  Future<({List<dynamic> presences, Map<String, dynamic>? summary})>
      getAllTodayPresences() async {
    try {
      final body = await _api.getRaw('presences/today');
      if (body['status'] == 'success' || body['success'] == true) {
        return (
          presences: body['data'] as List<dynamic>? ?? [],
          summary: body['summary'] as Map<String, dynamic>?,
        );
      }
      throw Exception(body['message'] ?? 'Gagal memuat presensi.');
    } catch (e) {
      developer.log('Error in getAllTodayPresences',
          error: e, name: 'PresenceService');
      return (presences: [], summary: null);
    }
  }

  Future<Map<String, dynamic>> getUserPresence() async {
    try {
      final data = await _api.getRaw('user-presence');
      developer.log('User Presence API Response: $data',
          name: 'PresenceService');
      return data;
    } catch (e) {
      developer.log('Error in getUserPresence',
          error: e, name: 'PresenceService');
      throw Exception('Failed to load presence data: $e');
    }
  }

  /// Returns true when the current user has an active clock-in for today.
  Future<bool> isClockedIn() async {
    try {
      final data = await getUserPresence();
      final presenceData = data['data'] as Map<String, dynamic>?;
      return presenceData?['today'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSalesOrders({
    int page = 1,
    int perPage = 10,
    int? deliveryStatus,
    bool? hasPaymentProof,
    bool? paymentProofPrinted,
    String? orderFor,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (deliveryStatus != null)
          'delivery_status': deliveryStatus.toString(),
        if (hasPaymentProof != null)
          'has_payment_proof': hasPaymentProof ? '1' : '0',
        if (paymentProofPrinted != null)
          'payment_proof_printed': paymentProofPrinted ? '1' : '0',
        if (orderFor != null) 'for': orderFor,
      };
      return await _api.getRaw('sales-orders/search',
          queryParams: queryParameters);
    } catch (e) {
      throw Exception('Error saat memuat daftar order: $e');
    }
  }

  Future<Map<String, dynamic>> markPaymentProofsPrinted({
    required List<int> orderIds,
  }) async {
    try {
      return await _api.postRaw(
        'sales-orders/payment-proofs/printed',
        body: {'order_ids': orderIds},
      );
    } catch (e) {
      throw Exception('Error saat memperbarui status print: $e');
    }
  }

  Future<Map<String, dynamic>> searchSalesOrder(String receiptNo,
      {String? orderFor}) async {
    try {
      final queryParams = <String, String>{
        'receipt_no': receiptNo,
        if (orderFor != null) 'for': orderFor,
      };
      return await _api.getRaw('sales-orders/search', queryParams: queryParams);
    } catch (e) {
      throw Exception('Error saat mencari resi: $e');
    }
  }

  /// Ganti seluruh item order (khusus admin). Items berupa list
  /// {product_id, quantity, unit_price}; [shippingCost] opsional — bila
  /// dikirim, ongkos kirim ikut diubah dan total_price dihitung ulang
  /// (items + ongkos kirim); bila null, nilai lama dipertahankan. Server
  /// mengembalikan order terbaru.
  Future<Map<String, dynamic>> updateSalesOrderItems({
    required int orderId,
    required List<Map<String, dynamic>> items,
    int? shippingCost,
  }) async {
    try {
      return await _api.postRaw(
        'sales-orders/$orderId/items',
        body: {
          'items': items,
          if (shippingCost != null) 'shipping_cost': shippingCost,
        },
      );
    } catch (e) {
      throw Exception('Error saat memperbarui rincian produk: $e');
    }
  }

  /// Ganti seluruh daftar foto bukti pengiriman order direct (khusus
  /// admin/super_admin, tanpa batasan status). Paths berupa daftar LENGKAP
  /// hasil edit (path lama yang dipertahankan + path baru); server menghapus
  /// file lama yang dibuang dan mengembalikan order terbaru.
  Future<Map<String, dynamic>> updateDeliveryPhotos({
    required int orderId,
    required List<String> paths,
  }) async {
    try {
      return await _api.postRaw(
        'sales-orders/$orderId/delivery-photos',
        body: {'image_delivery': paths},
      );
    } catch (e) {
      throw Exception('Error saat memperbarui foto pengiriman: $e');
    }
  }

  /// Detail satu order online (for=3) beserta items — dipakai deep-link
  /// notifikasi. Mengembalikan null bila order tidak ditemukan.
  Future<Map<String, dynamic>?> getOnlineSalesOrder(int id) async {
    try {
      final result = await _api.getRaw('sales-orders/online/$id');
      if (result['success'] == true &&
          result['data'] is Map<String, dynamic>) {
        return result['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> markReadyToShip({
    required int orderId,
    String? orderFor,
  }) async {
    try {
      final body = <String, dynamic>{'id': orderId};
      if (orderFor != null) body['for'] = orderFor;
      return await _api.postRaw('sales-orders/ready-to-ship', body: body);
    } catch (e) {
      throw Exception('Error saat mengubah status pengiriman: $e');
    }
  }

  /// Kept on raw http because callers inspect `success` in the full response
  /// body, which ApiClient._handleResponse strips to just `data`.
  /// Update status pengiriman sales order.
  ///
  /// [receiptNo] wajib untuk online order (for=3). [orderId] wajib untuk
  /// direct order (for=1). Salah satu harus diisi.
  /// [imageFiles] mendukung multi-upload; backend menyimpan sebagai JSON array
  /// path di kolom image_delivery.
  Future<Map<String, dynamic>> updateDeliveryStatus({
    String? receiptNo,
    int? orderId,
    List<File> imageFiles = const [],
    String? receivedBy,
    int? deliveryStatus,
    String? notes,
  }) async {
    final uri = Uri.parse(ApiConstants.updateDeliveryStatus);

    try {
      final fields = <String, String>{
        if (receiptNo != null && receiptNo.isNotEmpty) 'receipt_no': receiptNo,
        if (orderId != null) 'order_id': orderId.toString(),
        if (receivedBy != null && receivedBy.isNotEmpty)
          'received_by': receivedBy,
        if (deliveryStatus != null)
          'delivery_status': deliveryStatus.toString(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      // Upload tiap foto, kumpulkan path-nya, lalu kirim sebagai array
      // field berulang: image_delivery[0], image_delivery[1], dst.
      // Laravel akan terima sebagai array.
      for (var i = 0; i < imageFiles.length; i++) {
        final path = await ImageUploadService.upload(
          imageFiles[i],
          directory: 'images/Delivery',
        );
        if (path == null) {
          throw Exception('Gagal upload bukti pengiriman ke-${i + 1}.');
        }
        fields['image_delivery[$i]'] = path;
      }

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(await _getAuthHeaders())
        ..fields.addAll(fields);

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final decodedData = json.decode(responseData);

      if (response.statusCode == 200) {
        return decodedData;
      } else {
        throw Exception(
            decodedData['message'] ?? 'Gagal memperbarui status pengiriman.');
      }
    } catch (e) {
      throw Exception('Error saat memperbarui pengiriman: $e');
    }
  }

  /// Tetapkan status bayar &/atau toko untuk order direct (admin only).
  Future<Map<String, dynamic>> assignSalesOrder({
    required int orderId,
    String? paymentStatus,
    int? storeId,
  }) async {
    try {
      return await _api.postRaw(
        'sales-orders/$orderId/assign',
        body: {
          if (paymentStatus != null) 'payment_status': paymentStatus,
          if (storeId != null) 'store_id': storeId,
        },
      );
    } catch (e) {
      throw Exception('Error saat menetapkan toko/status bayar: $e');
    }
  }

  /// Check if there are pending utility reports for a store.
  Future<bool> checkPendingUtilityReports(int storeId) async {
    try {
      final body = await _api.getRaw(
        'utility-reports/pending',
        queryParams: {'store_id': storeId.toString()},
      );
      return body['has_pending'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Auth headers for multipart methods that need raw http responses.
  ///
  /// Token dibaca dari [TokenStore] (secure storage) — SAMA dengan [ApiClient].
  /// Sebelumnya ini membaca SharedPreferences, yang menjadi sumber bug 401
  /// saat check-in/check-out: `TokenStore.migrateFromPrefs()` menghapus token
  /// dari prefs, sehingga request multipart terkirim tanpa header Authorization.
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await TokenStore.instance.readToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
