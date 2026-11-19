import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/import_price_trend_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  Map<String, dynamic> point({
    required int importId,
    required String date,
    required double usd,
    required double idr,
    required bool realized,
    String currency = 'USD',
    double? usdVndRate,
  }) =>
      {
        'import_id': importId,
        'date': date,
        'supplier_name': 'Supplier $importId',
        'currency': currency,
        'exchange_rate': 17000,
        'usd_vnd_rate': usdVndRate,
        'quantity': 19500,
        'quantity_received': realized ? 19000 : null,
        'unit_price_foreign': usd,
        'unit_price_idr': idr,
        'unit_price_idr_estimate': idr - 500,
        'unit_price_idr_real': idr,
        'is_realized': realized,
      };

  http.Client mockClient() => MockClient((request) async {
        if (request.url.path.endsWith('/import-purchases/price-trends')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'product_id': 21,
                  'product_name': 'Mete Kernel BB2 (Carton 50 lb)',
                  'unit_name': 'kg',
                  'currency': 'USD',
                  'points': [
                    point(
                      importId: 1,
                      date: '2026-09-01',
                      usd: 0.75,
                      idr: 15000,
                      realized: false,
                    ),
                    point(
                      importId: 2,
                      date: '2026-10-01',
                      usd: 0.82,
                      idr: 17000,
                      realized: true,
                    ),
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

  testWidgets('trend harga — tampil IDR/realisasi dan bisa beralih ke USD',
      (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: ImportPriceTrendPage()),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.text('Trend Harga Satuan'), findsOneWidget);
      expect(find.text('Mete Kernel BB2 (Carton 50 lb)'), findsOneWidget);
      expect(find.text('Rp 17.000 / kg'), findsOneWidget);
      expect(find.text('Realisasi'), findsWidgets);

      await tester.tap(find.text('USD'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.text('USD 0,82 / kg'), findsOneWidget);
    }, () => mock);
  });

  testWidgets('trend harga — kartu diurutkan dari data terbaru',
      (tester) async {
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/import-purchases/price-trends')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'product_id': 1,
                'product_name': 'Produk Lama',
                'unit_name': 'kg',
                'currency': 'USD',
                'points': [
                  point(
                    importId: 1,
                    date: '2026-08-01',
                    usd: 0.70,
                    idr: 12000,
                    realized: true,
                  ),
                ],
              },
              {
                'product_id': 2,
                'product_name': 'Produk Baru',
                'unit_name': 'kg',
                'currency': 'USD',
                'points': [
                  point(
                    importId: 2,
                    date: '2026-10-01',
                    usd: 0.82,
                    idr: 17000,
                    realized: true,
                  ),
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

    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: ImportPriceTrendPage()),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      final newer = tester.getTopLeft(find.text('Produk Baru')).dy;
      final older = tester.getTopLeft(find.text('Produk Lama')).dy;
      expect(newer, lessThan(older));
    }, () => mock);
  });

  testWidgets(
      'kurs embedded transaksi > terpusat; tabel kurs manual tersimpan ke server',
      (tester) async {
    Map<String, dynamic>? ratePostBody;
    final knownRates = <String, double>{
      '2026-09-01': 25000,
      '2026-10-01': 26000,
    };
    // Kurs manual yang pernah di-POST — mock server stateful.
    final manualRates = <String, double>{};

    http.Response rateResponse(Map<String, dynamic> rates) => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'base': 'USD',
              'quote': 'VND',
              'latest': {'rate': 26150, 'date': '2026-10-22', 'source': 'public'},
              'rates': rates,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/import-purchases/price-trends')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'product_id': 21,
                'product_name': 'Mete Kernel BB2 (Carton 50 lb)',
                'unit_name': 'kg',
                'currency': 'USD',
                'points': [
                  // Transaksi USD membawa kurs embedded 25.500 (diinput
                  // saat create) — menang atas referensi per tanggal.
                  point(
                    importId: 1,
                    date: '2026-09-01',
                    usd: 0.80,
                    idr: 15000,
                    realized: false,
                    usdVndRate: 25500,
                  ),
                  // Transaksi VND lama tanpa kurs → jatuh ke referensi
                  // terpusat per tanggal.
                  point(
                    importId: 2,
                    date: '2026-10-01',
                    usd: 20800,
                    idr: 17000,
                    realized: true,
                    currency: 'VND',
                  ),
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      // Kurs terpusat: server me-resolve per tanggal yang diminta.
      if (path.endsWith('/currency-rates') && request.method == 'GET') {
        final dates = (request.url.queryParameters['dates'] ?? '')
            .split(',')
            .where((d) => d.isNotEmpty)
            .toList();
        return rateResponse({
          for (final d in dates)
            if (knownRates[d] != null || manualRates[d] != null)
              d: manualRates[d] != null
                  ? {
                      'rate': manualRates[d],
                      'source': 'manual',
                      'source_date': d,
                    }
                  : {
                      'rate': knownRates[d],
                      'source': 'public',
                      'source_date': d,
                    },
        });
      }
      // Simpan kurs manual satu tanggal.
      if (path.endsWith('/currency-rates') && request.method == 'POST') {
        ratePostBody = jsonDecode(request.body) as Map<String, dynamic>;
        manualRates[ratePostBody!['rate_date'].toString()] =
            (ratePostBody!['rate'] as num).toDouble();
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Kurs manual tersimpan.',
            'data': {
              'rate': ratePostBody!['rate'],
              'source': 'manual',
              'source_date': ratePostBody!['rate_date'],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: ImportPriceTrendPage()),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Rp 17.000 / kg'), findsOneWidget);

      // Mode VND: titik USD memakai kurs EMBEDDED transaksinya (25.500),
      // bukan referensi per tanggal (25.000) — 0,80 × 25.500 = 20.400.
      // Titik VND tampil mentah; format VND menyamai IDR (tanpa desimal).
      await tester.tap(find.text('VND'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('VND 20.800 / kg'), findsOneWidget);
      expect(find.text('VND 20.400'), findsOneWidget); // statistik Terendah

      // Tabel kurs: tanggal ber-transaksi read-only (chip 'Dari
      // transaksi'), tanggal tanpa kurs editable prefill publik.
      await tester.tap(find.text('Tabel kurs'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Kurs USD → VND per tanggal'), findsOneWidget);
      expect(find.text('1 Sep 2026'), findsOneWidget);
      expect(find.text('1 Okt 2026'), findsOneWidget);
      expect(find.text('Dari transaksi'), findsOneWidget);
      expect(find.text('25.500'), findsOneWidget);
      expect(find.widgetWithText(TextField, '26.000'), findsOneWidget);

      // Transaksi lama (1 Okt) tanpa kurs → isi manual 25.000; selesai
      // (ketuk luar) menyimpan ke server.
      await tester.enterText(
        find.widgetWithText(TextField, '26.000'),
        '25000',
      );
      await tester.tap(find.text('Selesai'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ratePostBody, isNotNull);
      expect(ratePostBody!['rate_date'], '2026-10-01');
      expect(ratePostBody!['rate'], 25000);

      // Mode USD: 20.800 VND ÷ 25.000 (manual 1 Okt) = 0,832 USD; titik
      // USD mentah 0,8.
      await tester.tap(find.text('USD'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('USD 0,832 / kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => mock);
  });
}
