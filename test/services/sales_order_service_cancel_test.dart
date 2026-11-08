import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/services/api_client.dart';
import 'package:sagansa/services/sales_order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// cancelOrder mengirim POST sales-orders/{id}/cancel dengan body {reason}
/// dan sukses saat backend 200; error backend dilempar sebagai ApiException.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  Future<void> run(Future<void> Function() body, MockClient mock) {
    return http.runWithClient(body, () => mock);
  }

  test('cancelOrder mengirim POST + reason dan sukses saat 200', () async {
    http.Request? captured;
    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Order berhasil dibatalkan.',
          'data': {'delivery_status': 7},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await run(
      () => SalesOrderService().cancelOrder(
        orderId: 42,
        reason: 'Dibatalkan oleh pembeli',
      ),
      mock,
    );

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.path, contains('/sales-orders/42/cancel'));
    expect(captured!.body, contains('Dibatalkan oleh pembeli'));
  });

  test('cancelOrder melempar ApiException saat backend menolak (400)',
      () async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Order sudah dibatalkan sebelumnya.',
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      run(
        () => SalesOrderService().cancelOrder(
          orderId: 42,
          reason: 'Dibatalkan oleh pembeli',
        ),
        mock,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
