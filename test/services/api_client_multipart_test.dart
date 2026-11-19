import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// multipart harus melempar ApiException berstatus & body ter-parse pada
/// non-2xx, agar service (mis. sales order online) bisa membaca
/// duplicate_receipt pada respons 409. 2xx tetap mengembalikan json['data'].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  test('multipart 409 → ApiException berstatusCode & body.duplicate_receipt',
      () async {
    final body = {
      'success': false,
      'message': 'Resi SPX123 sudah tercatat pada order #24278.',
      'duplicate_receipt': true,
      'data': {'existing_order_id': 24278},
    };
    final mock = MockClient.streaming((request, bodyStream) async {
      expect(request.method, 'POST');
      expect(request.url.path.endsWith('sales-orders/online'), isTrue);
      final multipart = request as http.MultipartRequest;
      expect(multipart.fields['idempotency_key'], 'k-1');
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        409,
      );
    });

    await http.runWithClient(() async {
      await expectLater(
        ApiClient().multipart(
          method: 'POST',
          path: 'sales-orders/online',
          fields: {'idempotency_key': 'k-1'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message',
                  'Resi SPX123 sudah tercatat pada order #24278.')
              .having((e) => e.body?['duplicate_receipt'],
                  'body.duplicate_receipt', isTrue),
        ),
      );
    }, () => mock);
  });

  test('multipart 2xx tetap mengembalikan json[data]', () async {
    final mock = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(utf8.encode(
            jsonEncode({'success': true, 'data': {'id': 7}}))),
        201,
      );
    });

    await http.runWithClient(() async {
      final data = await ApiClient().multipart(
        method: 'POST',
        path: 'sales-orders/online',
        fields: const {},
      );
      expect(data, {'id': 7});
    }, () => mock);
  });
}
