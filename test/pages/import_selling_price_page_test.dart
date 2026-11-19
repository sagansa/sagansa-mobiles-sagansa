import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/pages/import_selling_price_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test halaman Harga Jual (Info): kartu per produk, grid kemasan
/// 2×2 dengan harga terhitung dari konfigurasi mete, tanpa exception
/// layout (regresi: grid Row+stretch di tinggi tak terbatas pernah
/// menghasilkan layar kosong).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  http.Client mockClient() => MockClient((request) async {
        if (request.url.path.endsWith('/import-purchases/price-trends')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'product_id': 21,
                  'product_name': 'Mete Menir - BB2 (10kg)',
                  'unit_name': 'kg',
                  'currency': 'USD',
                  'points': [
                    {
                      'import_id': 1,
                      'date': '2026-10-01',
                      'supplier_name': 'Supplier Mete',
                      'currency': 'USD',
                      'exchange_rate': 17545,
                      'usd_vnd_rate': null,
                      'quantity': 12000,
                      'quantity_received': 11700,
                      'unit_price_foreign': 0.78,
                      'unit_price_idr': 30558,
                      'unit_price_idr_estimate': 29000,
                      'unit_price_idr_real': 30558,
                      'is_realized': true,
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ImportSellingPricePage()),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('harga jual — kartu, grid kemasan, harga terhitung', (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);
      expect(find.text('Mete Menir - BB2 (10kg)'), findsOneWidget);
      expect(find.text('Realisasi'), findsOneWidget);

      // HPP 30.558 → jangkar 10kg 43.000 (HPP +40%, dibulat ke atas);
      // 1kg 130% → 56.000; 100kg 90% → 39.000; 1 ton 80% → 34.000.
      expect(find.text('Rp 43.000'), findsOneWidget);
      expect(find.text('Rp 56.000'), findsOneWidget);
      expect(find.text('Rp 39.000'), findsOneWidget);
      expect(find.text('Rp 34.000'), findsOneWidget);
      expect(find.text('HPP +40%'), findsOneWidget);
      expect(find.text('130% dari 10kg'), findsOneWidget);
      expect(find.text('1 ton'), findsOneWidget);
    }, () => mock);
  });

  testWidgets('harga jual — layar kecil 320dp tanpa exception', (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.text('Rp 43.000'), findsOneWidget);
    }, () => mock);
  });
}
