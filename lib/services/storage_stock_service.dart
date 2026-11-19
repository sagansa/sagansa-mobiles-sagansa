import '../models/storage_stock_model.dart';
import 'api_client.dart';

class StorageStockService {
  final ApiClient _api = ApiClient();

  Future<List<StorageStockProduct>> getProducts() async {
    final data = await _api.get('storage-stocks/products');
    final List list = data as List;
    return list.map((item) => StorageStockProduct.fromJson(item)).toList();
  }

  Future<Map<String, dynamic>> getStorageStocks({int page = 1, int perPage = 20}) async {
    final response = await _api.getRaw(
      'storage-stocks',
      queryParams: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );
    final List data = response['data'];
    final reports = data.map((item) => StorageStockModel.fromJson(item)).toList();
    final pagination = response['pagination'] as Map<String, dynamic>?;
    return {
      'reports': reports,
      'has_more': (pagination?['current_page'] ?? 1) < (pagination?['last_page'] ?? 1),
    };
  }

  Future<List<Map<String, dynamic>>> getStockMonitoring() async {
    final data = await _api.get('storage-stocks/monitoring');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<StorageStockModel> getStorageStock(int id) async {
    final data = await _api.get('storage-stocks/$id');
    return StorageStockModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> createStorageStock(int storeId, List<Map<String, dynamic>> items) async {
    await _api.post('storage-stocks', body: {
      'store_id': storeId,
      'items': items,
    });
  }

  Future<void> updateStorageStock(int id, List<Map<String, dynamic>> items) async {
    await _api.put('storage-stocks/$id', body: {
      'items': items,
    });
  }

  Future<Map<String, int>> checkTodayStatus() async {
    final data = await _api.get('storage-stocks/today-status');
    if (data is! Map || data['success'] != true) {
      throw Exception('Status stok hari ini gagal dimuat.');
    }
    return {
      'total_stores': (data['total_stores'] as num?)?.toInt() ?? 0,
      'reported_stores': (data['reported_stores'] as num?)?.toInt() ?? 0,
      'user_store_reported': data['user_store_reported'] == true ? 1 : 0,
    };
  }

  Future<int> countReportedStoresToday() async {
    final status = await checkTodayStatus();
    return status['reported_stores'] ?? 0;
  }
}
