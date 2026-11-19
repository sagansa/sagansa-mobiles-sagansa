import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sagansa/pages/supplier_list_page.dart';
import 'package:sagansa/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test: list supplier (AppPageScaffold + GlassAppBar seamless +
/// pagination loadMore) tidak boleh melempar "setState during build" storm.
void main() {
  testWidgets('supplier list renders + paginates without build loop',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);

    Map<String, dynamic> supplierJson(int id, String name) => {
          'id': id,
          'name': name,
          'status': 2,
        };

    final mock = MockClient((request) async {
      final page = request.url.queryParameters['page'] ?? '1';
      final data = page == '1'
          ? [supplierJson(1, 'PT Maju Jaya'), supplierJson(2, 'CV Berkah')]
          : [];
      return http.Response(
        jsonEncode({
          'success': true,
          'data': data,
          'pagination': {'current_page': int.parse(page), 'last_page': 2},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(home: SupplierListPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final dynamic ex = tester.takeException();
      expect(ex, isNull);
      expect(find.text('PT Maju Jaya'), findsOneWidget);
      expect(find.text('CV Berkah'), findsOneWidget);
    }, () => mock);
  });
}
