import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/last_order_user_detail_model.dart';
import 'package:sagansa/pages/admin_last_order_user_detail_page.dart';
import 'package:sagansa/services/last_order_user_service.dart';

class _FakeService extends LastOrderUserService {
  _FakeService(this.detail);
  LastOrderUserDetail detail;
  final List<int> markCalls = [];

  @override
  Future<LastOrderUserDetail> getDetail(int userId) async => detail;

  @override
  Future<void> markFollowedUp(int userId) async {
    markCalls.add(userId);
    // Simulasi refresh: riwayat bertambah setelah ditandai.
    detail = LastOrderUserDetail(
      userId: detail.userId,
      name: detail.name,
      email: detail.email,
      lastOrderAt: detail.lastOrderAt,
      totalOrders: detail.totalOrders,
      totalNominal: detail.totalNominal,
      phones: detail.phones,
      products: detail.products,
      followUps: [
        LastOrderFollowUp(
          id: 99,
          byName: 'Sari Admin',
          createdAt: DateTime(2026, 10, 4, 8, 0),
        ),
        ...detail.followUps,
      ],
    );
  }
}

LastOrderUserDetail _detail({List<LastOrderFollowUp> followUps = const []}) =>
    LastOrderUserDetail(
      userId: 12,
      name: 'Budi',
      email: 'budi@contoh.com',
      totalOrders: 14,
      totalNominal: 12500000,
      phones: const ['0812-3456-7890'],
      products: const [
        LastOrderProductSummary(
          productId: 3,
          name: 'Gula Pasir',
          quantity: 120,
          unitPrice: 15000,
          total: 1800000,
        ),
        LastOrderProductSummary(
          productId: 4,
          name: 'Garam',
          quantity: 50,
          unitPrice: 4000,
          total: 200000,
        ),
      ],
      followUps: followUps,
    );

void main() {
  testWidgets('render info user, tabel produk, dan riwayat follow-up',
      (tester) async {
    final fake = _FakeService(_detail(followUps: [
      LastOrderFollowUp(id: 1, byName: 'Admin Lama', createdAt: DateTime(2026, 9, 1)),
    ]));

    await tester.pumpWidget(MaterialApp(
      home: AdminLastOrderUserDetailPage(userId: 12, service: fake),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Budi'), findsWidgets); // app bar + kartu info
    expect(find.text('budi@contoh.com'), findsOneWidget);
    expect(find.text('Gula Pasir'), findsOneWidget);
    expect(find.text('Garam'), findsOneWidget);
    expect(find.text('Admin Lama'), findsOneWidget);
    expect(find.text('Tandai Sudah Dihubungi'), findsOneWidget);
    expect(find.text('Produk Diorder'), findsOneWidget);
    expect(find.text('Total Produk'), findsOneWidget);
  });

  testWidgets('tandai sudah dihubungi memanggil service & menambah riwayat',
      (tester) async {
    final fake = _FakeService(_detail());

    await tester.pumpWidget(MaterialApp(
      home: AdminLastOrderUserDetailPage(userId: 12, service: fake),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Belum pernah dihubungi.'), findsOneWidget);

    await tester.tap(find.text('Tandai Sudah Dihubungi'));
    await tester.pumpAndSettle();

    expect(fake.markCalls, [12]);
    expect(find.text('Sari Admin'), findsOneWidget);
    expect(find.text('Belum pernah dihubungi.'), findsNothing);
  });
}
