import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sagansa/pages/supplier_detail_page.dart';
import 'package:sagansa/pages/supplier_form_page.dart';
import 'package:sagansa/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerbang asal supplier: hanya admin/super_admin yang boleh membuat dan
/// mengubah supplier luar negeri (paritas respons 403 backend). Non-admin
/// tidak melihat pilihan "Luar Negeri" di form, dan supervisor tidak
/// melihat tombol edit/hapus pada detail supplier luar negeri.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// Auth via mock: token di secure-storage + profil user di prefs.
  void seedAuth(List<String> roles) {
    SharedPreferences.setMockInitialValues({
      'user': jsonEncode({'roles': roles}),
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      if (call.method == 'read' && call.arguments['key'] == 'token') {
        return 'jwt-uji';
      }
      return null;
    });
  }

  http.Client mockClient() {
    return MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/provinces')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 9, 'name': 'Jawa Barat'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/banks')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 1, 'name': 'BCA'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/suppliers/5')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 5,
              'name': 'Olam Vietnam Ltd',
              'status': 2,
              'country_code': 'VN',
              'city_name': 'Ho Chi Minh City',
              'currency': 'USD',
              'bank_name': 'Vietcombank',
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
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(home: page),
      ),
    );
    // AuthProvider memuat token/user secara async; form memuat lookup.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Gulung ListView utama form (lewati scrollable internal TextField).
  Future<void> scrollTo(WidgetTester tester, double offset) async {
    final scrollableFinder = find.byWidgetPredicate((w) =>
        w is Scrollable &&
        w.axisDirection == AxisDirection.down &&
        w.restorationId == null);
    final state = tester.state<ScrollableState>(scrollableFinder);
    state.position.jumpTo(offset.clamp(0, state.position.maxScrollExtent));
    await tester.pumpAndSettle();
  }

  testWidgets('admin melihat pilihan asal Domestik/Luar Negeri', (tester) async {
    seedAuth(['admin']);
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const SupplierFormPage());
      expect(tester.takeException(), isNull);
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(find.text('Domestik'), findsOneWidget);
      expect(find.text('Luar Negeri'), findsOneWidget);
      // Default domestik: seksi alamat wilayah Indonesia tetap ada.
      await scrollTo(tester, 700);
      // Label dropdown dirender sebagai rich text — cocokkan via substring.
      expect(find.textContaining('Provinsi'), findsOneWidget);
    }, () => mock);
  });

  testWidgets('non-admin tidak diberi pilihan Luar Negeri', (tester) async {
    seedAuth(['supervisor']);
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const SupplierFormPage());
      expect(tester.takeException(), isNull);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.text('Luar Negeri'), findsNothing);
      expect(find.text('Domestik'), findsNothing);
      // Penjelas aturan tetap tampil, form kembali ke perilaku domestik.
      expect(find.text('Supplier luar negeri hanya dapat dibuat oleh admin.'),
          findsOneWidget);
      await scrollTo(tester, 700);
      expect(find.textContaining('Provinsi'), findsOneWidget);
      expect(find.textContaining('Valuta Transaksi'), findsNothing);
    }, () => mock);
  });

  testWidgets('supervisor tidak melihat edit/hapus supplier luar negeri',
      (tester) async {
    seedAuth(['supervisor']);
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const SupplierDetailPage(supplierId: 5));
      expect(tester.takeException(), isNull);
      expect(find.text('Olam Vietnam LTD'), findsWidgets);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Hapus'), findsNothing);
      // Foto (perubahan gambar) tetap boleh untuk supervisor.
      expect(find.text('Tambah Foto'), findsOneWidget);
    }, () => mock);
  });

  testWidgets('admin tetap melihat edit/hapus supplier luar negeri',
      (tester) async {
    seedAuth(['admin']);
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const SupplierDetailPage(supplierId: 5));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Hapus'), findsOneWidget);
    }, () => mock);
  });
}
