import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/widgets/delivery/order_list_card.dart';

Map<String, dynamic> directListOrder({Object? shippingCost = 25000}) => {
      'id': 11739,
      'store_name': 'Toko A',
      'payment_method': 'manual_transfer',
      'delivery_service_name': 'Via Us',
      'payment_status': '1',
      'delivery_status': 1,
      'total_price': 80000,
      'shipping_cost': shippingCost,
      'address_detail': null,
      'items': <Map<String, dynamic>>[],
    };

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required Map<String, dynamic> order,
    required bool isAdmin,
  }) async {
    await tester.pumpWidget(wrap(OrderListCard(
      order: order,
      orderMode: OrderMode.direct,
      isAdmin: isAdmin,
      isStickerPrinted: false,
      isPrintingSticker: false,
      onTap: () {},
    )));
    await tester.pump();
  }

  testWidgets('admin melihat baris ongkir saat shipping_cost ada',
      (tester) async {
    await pumpCard(tester, order: directListOrder(), isAdmin: true);

    expect(find.text('Ongkir: Rp 25.000'), findsOneWidget);
    expect(find.text('Rp 80.000'), findsOneWidget); // total tetap tampil
  });

  testWidgets('shipping_cost null: baris ongkir tidak tampil', (tester) async {
    await pumpCard(
      tester,
      order: directListOrder(shippingCost: null),
      isAdmin: true,
    );

    expect(find.textContaining('Ongkir'), findsNothing);
  });

  testWidgets('non-admin tidak melihat ongkir maupun nominal', (tester) async {
    await pumpCard(tester, order: directListOrder(), isAdmin: false);

    expect(find.textContaining('Ongkir'), findsNothing);
    expect(find.text('Rp 80.000'), findsNothing);
  });
}
