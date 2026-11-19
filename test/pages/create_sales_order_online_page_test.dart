import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/sales_order_online_model.dart';
import 'package:sagansa/models/store_model.dart';
import 'package:sagansa/pages/create_sales_order_online_page.dart';
import 'package:sagansa/services/sales_order_service.dart';
import 'package:sagansa/services/store_service.dart';
import 'package:sagansa/widgets/modern_dropdown.dart';

class _FakeStoreService extends StoreService {
  _FakeStoreService(this.stores);
  final List<StoreModel> stores;

  @override
  Future<List<StoreModel>> getStores() async => stores;
}

class _FakeSalesOrderService extends SalesOrderService {
  _FakeSalesOrderService(
    this.products, {
    this.throwOnFirstSubmit = false,
  });

  final List<SalesOrderOnlineProduct> products;
  final bool throwOnFirstSubmit;
  final List<Map<String, dynamic>> createCalls = [];

  @override
  Future<List<SalesOrderOnlineProduct>> getOnlineProducts() async => products;

  @override
  Future<List<OnlineShopProvider>> getOnlineShopProviders() async =>
      [OnlineShopProvider(id: 1, name: 'Shopee')];

  @override
  Future<List<DeliveryServiceOption>> getDeliveryServices() async =>
      [DeliveryServiceOption(id: 1, name: 'JNE')];

  @override
  Future<void> createOnlineOrder({
    required Store selectedStore,
    required String deliveryDate,
    required int onlineShopProviderId,
    required int deliveryServiceId,
    required String receiptNo,
    required List<SalesOrderItemRequest> items,
    required String idempotencyKey,
    bool confirmDuplicateReceipt = false,
    File? imagePayment,
    Uint8List? imagePaymentBytes,
  }) async {
    createCalls.add({
      'idempotency_key': idempotencyKey,
      'confirm': confirmDuplicateReceipt,
      'receipt_no': receiptNo,
    });
    if (throwOnFirstSubmit && createCalls.length == 1) {
      throw DuplicateReceiptException(
        message: 'Resi SPX123 sudah tercatat pada order #24278.',
        existingOrderId: 24278,
        receiptNo: 'SPX123',
        deliveryDate: '2026-11-01',
        totalPrice: 150000,
        storeNickname: 'Toko A',
        existingCreatedAt: '2026-11-03 10:00:00',
      );
    }
  }
}

StoreModel _store(int id, String nickname) => StoreModel(
      id: id,
      nickname: nickname,
      latitude: 0,
      longitude: 0,
    );

SalesOrderOnlineProduct _product(int id, String name) =>
    SalesOrderOnlineProduct(id: id, name: name, unit: 'kg');

void main() {
  testWidgets(
      '409 resi duplikat: dialog konfirmasi muncul, Tetap Simpan mengirim key SAMA + confirm=true',
      (tester) async {
    // Viewport tinggi agar seluruh form (tombol "Tambah" di bawah header)
    // ter-build dan bisa di-tap tanpa scroll manual.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final salesOrder = _FakeSalesOrderService(
      [_product(101, 'Mete Utuh')],
      throwOnFirstSubmit: true,
    );

    // Push lewat tombol agar Navigator.pop setelah submit punya tujuan.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateSalesOrderOnlinePage(
                    storeService: _FakeStoreService([_store(1, 'Toko A')]),
                    salesOrderService: salesOrder,
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

    // Isi form minimal: Toko, Provider, Delivery Service, resi, 1 item.
    await tester.tap(find.byType(ModernDropdown<StoreModel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toko A').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ModernDropdown<OnlineShopProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopee').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ModernDropdown<DeliveryServiceOption>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JNE').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nomor Resi *'),
      'SPX123',
    );

    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ModernDropdown<SalesOrderOnlineProduct>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mete Utuh').last);
    await tester.pumpAndSettle();

    // Submit pertama → DuplicateReceiptException → dialog konfirmasi.
    // _isSubmitting sengaja tetap true selama dialog terbuka (spinner di
    // belakang dialog berputar terus), jadi pumpAndSettle tidak akan settle —
    // gunakan pump tetap hingga animasi dialog masuk selesai.
    await tester.tap(find.text('Simpan Sales Order'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(salesOrder.createCalls, hasLength(1));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('#24278'), findsOneWidget);

    // Retry dengan konfirmasi.
    await tester.tap(find.text('Tetap Simpan'));
    await tester.pumpAndSettle();

    expect(salesOrder.createCalls, hasLength(2));
    expect(salesOrder.createCalls[0]['confirm'], isFalse);
    expect(salesOrder.createCalls[1]['confirm'], isTrue);
    // KRITIS: key yang sama dipakai ulang — inilah yang membuat backend
    // mengenali retry dan tidak menciptakan double order.
    expect(salesOrder.createCalls[0]['idempotency_key'],
        salesOrder.createCalls[1]['idempotency_key']);
    expect(salesOrder.createCalls[1]['idempotency_key'], isNotEmpty);
  });
}
