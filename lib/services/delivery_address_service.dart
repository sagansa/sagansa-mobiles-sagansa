import '../models/delivery_address_model.dart';
import 'api_client.dart';

/// CRUD calon konsumen (DeliveryAddress) milik user sales.
class DeliveryAddressService {
  final ApiClient _api = ApiClient();

  /// List konsumen milik user login.
  Future<List<DeliveryAddressModel>> getList() async {
    final data = await _api.get('delivery-addresses');
    return (data as List<dynamic>? ?? const [])
        .map((e) =>
            DeliveryAddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryAddressModel> getDetail(int id) async {
    final data = await _api.get('delivery-addresses/$id');
    return DeliveryAddressModel.fromJson((data as Map<String, dynamic>?) ?? {});
  }

  /// Payload: name, recipient_name, recipient_telp_no, address, province_id,
  /// city_id, district_id?, subdistrict_id?, postal_code_id?, latitude?,
  /// longitude? (field nullable yang null TIDAK dikirim).
  Future<DeliveryAddressModel> create(Map<String, dynamic> payload) async {
    final data = await _api.post('delivery-addresses', body: payload);
    return DeliveryAddressModel.fromJson(
        (data as Map<String, dynamic>?) ?? {});
  }

  Future<DeliveryAddressModel> update(
      int id, Map<String, dynamic> payload) async {
    final data = await _api.put('delivery-addresses/$id', body: payload);
    return DeliveryAddressModel.fromJson(
        (data as Map<String, dynamic>?) ?? {});
  }
}