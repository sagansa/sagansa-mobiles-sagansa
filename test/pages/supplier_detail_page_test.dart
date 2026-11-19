import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sagansa/pages/supplier_detail_page.dart';
import 'package:sagansa/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test untuk SupplierDetailPage.
///
/// Menjamin jalur sukses (loading → konten SliverAppBar + CustomScrollView)
/// ter-render tanpa "setState() called during build" storm.
void main() {
  testWidgets('detail supplier success path: no build loop', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/suppliers/1')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 1,
              'name': 'PT Maju Jaya',
              'status': 2,
              'no_telp': '081234567',
              'bank': {'name': 'BCA'},
              'bank_account_no': '1234567890',
              'city': {'name': 'Bandung'},
              'image': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'success': false, 'message': 'not found'}),
        404,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: SupplierDetailPage(supplierId: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Kuras frame: bila ada rebuild loop, takeException menangkapnya.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final dynamic ex = tester.takeException();
      expect(ex, isNull);
      expect(find.text('PT Maju Jaya'), findsWidgets);
      expect(find.text('Valid'), findsOneWidget);
    }, () => mock);
  });
}
