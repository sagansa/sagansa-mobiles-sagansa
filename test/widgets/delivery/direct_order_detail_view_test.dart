import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sagansa/models/enums/delivery_status.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/providers/delivery_provider.dart';
import 'package:sagansa/providers/printer_provider.dart';
import 'package:sagansa/services/delivery_status_repository.dart';
import 'package:sagansa/services/payment_proof_pdf_service.dart';
import 'package:sagansa/services/presence_service.dart';
import 'package:sagansa/services/sticker_print_orchestrator.dart';
import 'package:sagansa/widgets/delivery/direct_order_detail_view.dart';

class _MockPresence extends Mock implements PresenceService {}

class _MockRepository extends Mock implements DeliveryStatusRepository {}

class _MockPdf extends Mock implements PaymentProofPdfService {}

class _MockSticker extends Mock implements StickerPrintOrchestrator {}

Map<String, dynamic> directOrder({int deliveryStatus = 4}) => {
      'id': 11739,
      'store_name': 'Toko A',
      'payment_method': 'transfer',
      'payment_status': '1',
      'delivery_status': deliveryStatus,
      'total_price': 410000,
      'items': [
        {
          'quantity': 2,
          'product_unit': 'pcs',
          'product_name': 'Biji Wijen Putih',
          'unit_price': 55000,
          'subtotal_price': 110000,
        },
        {
          'quantity': 1,
          'product_unit': 'bal',
          'product_name': 'Mete Menir BB2',
          'unit_price': 300000,
          'subtotal_price': 300000,
        },
      ],
    };

Future<DeliveryProvider> makeProvider({
  required bool isAdmin,
  Map<String, dynamic> Function()? onUpdateDeliveryStatus,
}) async {
  final presence = _MockPresence();
  final repo = _MockRepository();
  when(() => repo.loadAdminRole()).thenAnswer((_) async => isAdmin);
  when(() => repo.loadCanManageSalesLink()).thenAnswer((_) async => false);
  when(() => repo.loadPrintedStickers()).thenAnswer((_) async => {});
  when(() => presence.getSalesOrders(
        page: any(named: 'page'),
        perPage: any(named: 'perPage'),
        deliveryStatus: any(named: 'deliveryStatus'),
        hasPaymentProof: any(named: 'hasPaymentProof'),
        paymentProofPrinted: any(named: 'paymentProofPrinted'),
        orderFor: any(named: 'orderFor'),
      )).thenAnswer((_) async =>
      {'success': true, 'data': [], 'meta': {'last_page': 1}});

  final stub = onUpdateDeliveryStatus;
  if (stub != null) {
    when(() => presence.updateDeliveryStatus(
          receiptNo: any(named: 'receiptNo'),
          orderId: any(named: 'orderId'),
          imageFiles: any(named: 'imageFiles'),
          receivedBy: any(named: 'receivedBy'),
          deliveryStatus: any(named: 'deliveryStatus'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) async => stub());
  }

  final provider = DeliveryProvider(
    orderMode: OrderMode.direct,
    presenceService: presence,
    repository: repo,
    pdfService: _MockPdf(),
    stickerOrchestrator: _MockSticker(),
  );
  await provider.initialize();
  return provider;
}

Future<void> pumpDetail(
  WidgetTester tester, {
  required DeliveryProvider provider,
  required Map<String, dynamic> order,
  required DeliveryStatus status,
}) async {
  provider.selectOrder(order);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DeliveryProvider>.value(value: provider),
      ChangeNotifierProvider<PrinterProvider>(create: (_) => PrinterProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: DirectOrderDetailView(
          order: order,
          orderMode: OrderMode.direct,
          status: status,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(<File>[]);
  });

  testWidgets('form kirim bukti: tanpa chip Sudah Dikirim/Dikembalikan',
      (tester) async {
    final provider = await makeProvider(isAdmin: false);
    await pumpDetail(
      tester,
      provider: provider,
      order: directOrder(deliveryStatus: 4),
      status: DeliveryStatus.ready,
    );

    expect(find.text('Sudah Dikirim'), findsNothing);
    expect(find.text('Dikembalikan'), findsNothing);
    expect(find.text('Kirim Bukti Pengiriman'), findsWidgets);
  });

  testWidgets('status siap dikirim: tombol refund tidak tampil', (tester) async {
    final provider = await makeProvider(isAdmin: false);
    await pumpDetail(
      tester,
      provider: provider,
      order: directOrder(deliveryStatus: 4),
      status: DeliveryStatus.ready,
    );

    expect(find.text('Refund / Kembalikan Order'), findsNothing);
  });

  testWidgets('status perbaiki: tombol refund tampil', (tester) async {
    final provider = await makeProvider(isAdmin: false);
    await pumpDetail(
      tester,
      provider: provider,
      order: directOrder(deliveryStatus: 5),
      status: DeliveryStatus.fix,
    );

    expect(find.text('Refund / Kembalikan Order'), findsOneWidget);
  });

  testWidgets('refund gagal: form pulih ke mode kirim dan snackbar error',
      (tester) async {
    final provider = await makeProvider(
      isAdmin: false,
      onUpdateDeliveryStatus: () =>
          throw Exception('Refund gagal disimulasikan'),
    );
    await pumpDetail(
      tester,
      provider: provider,
      order: directOrder(deliveryStatus: 5),
      status: DeliveryStatus.fix,
    );

    await tester.ensureVisible(find.text('Refund / Kembalikan Order'));
    await tester.pump();
    await tester.tap(find.text('Refund / Kembalikan Order'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Laporkan Barang Kembali'), findsNothing);
    expect(find.text('Kirim Bukti Pengiriman'), findsWidgets);
    expect(find.text('Refund gagal disimulasikan'), findsOneWidget);
  });

  testWidgets('admin melihat harga per item dan Total Harga', (tester) async {
    final provider = await makeProvider(isAdmin: true);
    await pumpDetail(
      tester,
      provider: provider,
      order: directOrder(deliveryStatus: 4),
      status: DeliveryStatus.ready,
    );

    expect(find.text('Total Harga'), findsOneWidget);
    expect(find.text('Rp 55.000 x 2 = Rp 110.000'), findsOneWidget);
    expect(find.text('Rp 410.000'), findsOneWidget);
  });

  testWidgets('non-admin tidak melihat harga maupun Total Harga',
      (tester) async {
    final provider = await makeProvider(isAdmin: false);
    await pumpDetail(
      tester,
      provider: provider,
      order: directOrder(deliveryStatus: 4),
      status: DeliveryStatus.ready,
    );

    expect(find.text('Total Harga'), findsNothing);
    expect(find.textContaining('x 2 = Rp 110.000'), findsNothing);
  });
}
