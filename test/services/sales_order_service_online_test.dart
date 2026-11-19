import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/models/sales_order_online_model.dart';
import 'package:sagansa/models/store_model.dart';
import 'package:sagansa/services/sales_order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// createOnlineOrder mengirim idempotency_key + confirm_duplicate_receipt,
/// dan menerjemahkan 409 duplicate_receipt menjadi DuplicateReceiptException
/// berisi detail order existing untuk dialog konfirmasi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  // Store adalah typedef StoreModel; latitude/longitude required di model.
  final store = StoreModel(
    id: 3,
    nickname: 'Toko A',
    latitude: 0,
    longitude: 0,
  );

  final item = SalesOrderItemRequest(
    productId: 1,
    quantity: 2,
    unitPrice: 5000,
  );

  Future<void> run(Future<void> Function() body, MockClient mock) {
    return http.runWithClient(body, () => mock);
  }

  MockClient mockSuccess({Map<String, String>? captured}) {
    return MockClient.streaming((request, bodyStream) async {
      if (captured != null) {
        captured.addAll((request as http.MultipartRequest).fields);
      }
      return http.StreamedResponse(
        Stream.value(
            utf8.encode(jsonEncode({'success': true, 'data': {'id': 1}}))),
        201,
      );
    });
  }

  test('createOnlineOrder mengirim idempotency_key dan confirm flag',
      () async {
    final fields = <String, String>{};
    final mock = mockSuccess(captured: fields);

    await run(
      () => SalesOrderService().createOnlineOrder(
        selectedStore: store,
        deliveryDate: '2026-11-06',
        onlineShopProviderId: 1,
        deliveryServiceId: 1,
        receiptNo: 'SPX123',
        items: [item],
        idempotencyKey: 'uuid-abc',
      ),
      mock,
    );

    expect(fields['idempotency_key'], 'uuid-abc');
    expect(fields['confirm_duplicate_receipt'], isNull);
    expect(fields['receipt_no'], 'SPX123');
  });

  test('409 duplicate_receipt → DuplicateReceiptException berisi detail',
      () async {
    final mock = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'success': false,
          'message': 'Resi SPX123 sudah tercatat pada order #24278.',
          'duplicate_receipt': true,
          'data': {
            'existing_order_id': 24278,
            'receipt_no': 'SPX123',
            'delivery_date': '2026-11-01',
            'total_price': 150000,
            'store_nickname': 'Toko A',
            'existing_created_at': '2026-11-03 10:00:00',
          },
        }))),
        409,
      );
    });

    await expectLater(
      run(
        () => SalesOrderService().createOnlineOrder(
          selectedStore: store,
          deliveryDate: '2026-11-06',
          onlineShopProviderId: 1,
          deliveryServiceId: 1,
          receiptNo: 'SPX123',
          items: [item],
          idempotencyKey: 'uuid-abc',
        ),
        mock,
      ),
      throwsA(
        isA<DuplicateReceiptException>()
            .having((e) => e.existingOrderId, 'existingOrderId', 24278)
            .having((e) => e.receiptNo, 'receiptNo', 'SPX123')
            .having((e) => e.totalPrice, 'totalPrice', 150000)
            .having((e) => e.storeNickname, 'storeNickname', 'Toko A')
            .having((e) => e.toString(), 'toString',
                'Resi SPX123 sudah tercatat pada order #24278.'),
      ),
    );
  });

  test('confirmDuplicateReceipt=true dikirim sebagai true', () async {
    final fields = <String, String>{};
    final mock = mockSuccess(captured: fields);

    await run(
      () => SalesOrderService().createOnlineOrder(
        selectedStore: store,
        deliveryDate: '2026-11-06',
        onlineShopProviderId: 1,
        deliveryServiceId: 1,
        receiptNo: 'SPX123',
        items: [item],
        idempotencyKey: 'uuid-abc',
        confirmDuplicateReceipt: true,
      ),
      mock,
    );

    expect(fields['confirm_duplicate_receipt'], 'true');
  });
}
