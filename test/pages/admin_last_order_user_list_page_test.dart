import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/last_order_user_detail_model.dart';
import 'package:sagansa/models/last_order_user_model.dart';
import 'package:sagansa/pages/admin_last_order_user_list_page.dart';
import 'package:sagansa/services/last_order_user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeService extends LastOrderUserService {
  _FakeService(this.pages);
  final Map<int, (List<LastOrderUserModel>, bool)> pages;
  final List<Map<String, dynamic>> calls = [];
  LastOrderUserDetail detail = const LastOrderUserDetail(
    userId: 12,
    name: 'Budi',
    email: 'budi@contoh.com',
    phones: [],
    products: [],
    followUps: [],
  );

  @override
  Future<(List<LastOrderUserModel>, bool)> getList({
    int page = 1,
    int perPage = 20,
    String? search,
    String sort = 'last_order_desc',
    bool? hasPhone,
  }) async {
    calls.add({
      'page': page,
      'sort': sort,
      'search': search,
      'hasPhone': hasPhone,
    });
    return pages.putIfAbsent(page, () => (<LastOrderUserModel>[], false));
  }

  @override
  Future<LastOrderUserDetail> getDetail(int userId) async => detail;
}

LastOrderUserModel _row(
  int userId,
  String name, {
  DateTime? lastFollowUpAt,
  String? lastFollowUpByName,
}) =>
    LastOrderUserModel(
      userId: userId,
      name: name,
      email: '$name@contoh.com',
      lastOrderAt: DateTime(2026, 10, 1, 9, 30),
      totalOrders: 3,
      totalNominal: 450000,
      phones: const ['0812-3456-7890'],
      lastFollowUpAt: lastFollowUpAt,
      lastFollowUpByName: lastFollowUpByName,
    );

Future<void> pumpPage(
  WidgetTester tester, {
  required LastOrderUserService service,
  List<String> roles = const ['admin'],
  Future<void> Function(Uri url)? launcher,
}) async {
  SharedPreferences.setMockInitialValues({
    'user': jsonEncode({'roles': roles}),
  });
  await tester.pumpWidget(MaterialApp(
    home: AdminLastOrderUserListPage(
      service: service,
      launchUrlImpl: launcher,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('render baris user + chip no telp + marker follow-up',
      (tester) async {
    final fake = _FakeService({
      1: ([
        _row(12, 'Budi',
            lastFollowUpAt: DateTime(2026, 10, 3),
            lastFollowUpByName: 'Sari Admin'),
      ], false),
    });

    await pumpPage(tester, service: fake);

    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Budi@contoh.com'), findsOneWidget);
    expect(find.text('0812-3456-7890'), findsOneWidget);
    expect(find.textContaining('Dihubungi'), findsOneWidget);
    expect(find.textContaining('Sari Admin'), findsOneWidget);
  });

  testWidgets(
      'filter sheet: urutan Terlama + punya no telp + pencarian diteruskan ke service',
      (tester) async {
    final fake = _FakeService({
      1: ([_row(12, 'Budi')], false),
    });
    await pumpPage(tester, service: fake);
    expect(fake.calls.last['sort'], 'last_order_desc');

    // Buka sheet lewat pill kanan-atas.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    // Isi pencarian, pilih urutan Terlama & Punya no telp, lalu Terapkan.
    await tester.enterText(find.byType(TextField), 'budi@contoh.com');
    await tester.tap(find.text('Terlama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punya no telp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    expect(fake.calls.last['page'], 1);
    expect(fake.calls.last['sort'], 'last_order_asc');
    expect(fake.calls.last['search'], 'budi@contoh.com');
    expect(fake.calls.last['hasPhone'], isTrue);

    // Badge jumlah filter aktif (2) muncul di pill.
    expect(find.byIcon(Icons.filter_list_off), findsOneWidget);
  });

  testWidgets('hapus filter mereset semua', (tester) async {
    final fake = _FakeService({
      1: ([_row(12, 'Budi')], false),
    });
    await pumpPage(tester, service: fake);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punya no telp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(fake.calls.last['hasPhone'], isTrue);

    await tester.tap(find.byIcon(Icons.filter_list_off));
    await tester.pumpAndSettle();

    expect(fake.calls.last['hasPhone'], isNull);
    expect(fake.calls.last['sort'], 'last_order_desc');
  });

  testWidgets('tap chip no telp membuka wa.me ternormalisasi', (tester) async {
    Uri? launched;
    final fake = _FakeService({
      1: ([_row(12, 'Budi')], false),
    });

    await pumpPage(
      tester,
      service: fake,
      launcher: (uri) async => launched = uri,
    );

    await tester.tap(find.text('0812-3456-7890'));
    await tester.pumpAndSettle();

    expect(launched.toString(), 'https://wa.me/6281234567890');
  });

  testWidgets('tap kartu membuka detail user', (tester) async {
    final fake = _FakeService({
      1: ([_row(12, 'Budi')], false),
    });

    await pumpPage(tester, service: fake);

    await tester.tap(find.text('Budi'));
    await tester.pumpAndSettle();

    expect(find.text('Follow-up'), findsOneWidget);
    expect(find.text('Produk Diorder'), findsOneWidget);
  });

  testWidgets('non-admin hanya melihat pesan guard', (tester) async {
    final fake = _FakeService({
      1: ([_row(12, 'Budi')], false),
    });

    await pumpPage(tester, service: fake, roles: ['sales']);

    expect(find.text('Halaman ini khusus admin.'), findsOneWidget);
    expect(find.text('Budi'), findsNothing);
    expect(fake.calls, isEmpty);
  });
}
