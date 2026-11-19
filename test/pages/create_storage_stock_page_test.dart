import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/storage_stock_model.dart';
import 'package:sagansa/models/store_model.dart';
import 'package:sagansa/pages/create_storage_stock_page.dart';
import 'package:sagansa/services/storage_stock_service.dart';
import 'package:sagansa/services/store_service.dart';

class _FakeStoreService extends StoreService {
  _FakeStoreService(this.stores);
  final List<StoreModel> stores;

  @override
  Future<List<StoreModel>> getStores() async => stores;
}

class _FakeStorageStockService extends StorageStockService {
  _FakeStorageStockService(this.products);
  final List<StorageStockProduct> products;
  final List<Map<String, dynamic>> updateCalls = [];

  @override
  Future<List<StorageStockProduct>> getProducts() async => products;

  @override
  Future<void> updateStorageStock(int id, List<Map<String, dynamic>> items) async {
    updateCalls.add({'id': id, 'items': items});
  }
}

StorageStockProduct _product(int id, String name) =>
    StorageStockProduct(id: id, name: name, unitName: 'kg');

void main() {
  testWidgets('mode edit: judul, qty prefilled, submit ke update', (tester) async {
    final report = StorageStockModel(
      id: 12,
      storeId: 3,
      date: '2026-09-20',
      status: 1,
      storeName: 'Gudang Pusat',
      createdByName: 'Budi',
      details: [
        ProductStorageStockModel(
          id: 1,
          productId: 101,
          quantity: 12,
          productName: 'Gula',
          unitName: 'kg',
        ),
      ],
    );
    final fakeStorage = _FakeStorageStockService([
      _product(101, 'Gula'),
      _product(102, 'Garam'),
    ]);
    final fakeStores = _FakeStoreService([
      StoreModel(id: 3, nickname: 'Gudang Pusat', latitude: 0, longitude: 0),
    ]);

    // Push lewat tombol agar Navigator.pop setelah submit punya tujuan.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateStorageStockPage(
                    reportForEdit: report,
                    storeService: fakeStores,
                    storageStockService: fakeStorage,
                  ),
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Stock Opname'), findsOneWidget);

    // Qty Gula prefilled 12; Garam (produk baru) 0.
    expect(find.widgetWithText(TextFormField, '12'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '0'), findsOneWidget);

    // Dropdown terkunci ke gudang laporan.
    expect(find.text('Gudang Pusat'), findsWidgets);

    await tester.tap(find.text('Simpan Perubahan Stock Opname'));
    await tester.pumpAndSettle();

    expect(fakeStorage.updateCalls, hasLength(1));
    expect(fakeStorage.updateCalls.first['id'], 12);
    final items = fakeStorage.updateCalls.first['items'] as List;
    expect(
      items.firstWhere((i) => i['product_id'] == 101)['quantity'],
      12.0,
    );
  });

  testWidgets('mode create: judul biasa, tombol create', (tester) async {
    final fakeStorage = _FakeStorageStockService([_product(101, 'Gula')]);
    final fakeStores = _FakeStoreService(
        [StoreModel(id: 3, nickname: 'Gudang Pusat', latitude: 0, longitude: 0)]);

    await tester.pumpWidget(MaterialApp(
      home: CreateStorageStockPage(
        storeService: fakeStores,
        storageStockService: fakeStorage,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Stock Opname Baru'), findsOneWidget);
    expect(find.text('Simpan Stock Opname'), findsOneWidget);
    expect(find.text('Simpan Perubahan Stock Opname'), findsNothing);
  });
}
