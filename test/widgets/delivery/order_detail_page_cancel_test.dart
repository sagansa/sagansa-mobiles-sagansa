import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/providers/delivery_provider.dart';
import 'package:sagansa/services/delivery_status_repository.dart';
import 'package:sagansa/services/payment_proof_pdf_service.dart';
import 'package:sagansa/services/presence_service.dart';
import 'package:sagansa/services/sales_order_service.dart';
import 'package:sagansa/services/sticker_print_orchestrator.dart';
import 'package:sagansa/widgets/delivery/order_detail_page.dart';

class _MockPresence extends Mock implements PresenceService {}

class _MockRepository extends Mock implements DeliveryStatusRepository {}

class _MockPdf extends Mock implements PaymentProofPdfService {}

class _MockSticker extends Mock implements StickerPrintOrchestrator {}

class _MockSalesOrderService extends Mock implements SalesOrderService {}

/// Fitur pembatalan order online oleh admin di halaman detail:
///  - admin + status 4: tombol tampil → dialog → confirm → status jadi
///    "Dibatalkan" + alasan tampil, tombol hilang.
///  - non-admin: tombol tidak tampil.
///  - admin + status 3 (sudah dikirim): tombol tidak tampil (pakai refund).
void main() {
  late _MockPresence presence;
  late _MockSalesOrderService sales;
  late _MockRepository repo;

  Future<DeliveryProvider> buildProvider({required bool admin}) async {
    when(() => repo.loadAdminRole()).thenAnswer((_) async => admin);
    when(() => repo.loadCanManageSalesLink()).thenAnswer((_) async => false);
    when(() => repo.loadDeliveryPhotoEditRole()).thenAnswer((_) async => false);
    when(() => repo.loadPrintedStickers()).thenAnswer((_) async => {});
    when(() => presence.getSalesOrders(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          orderFor: any(named: 'orderFor'),
        )).thenAnswer((_) async => {
              'success': true,
              'data': [],
              'meta': {'last_page': 1},
            });

    final provider = DeliveryProvider(
      orderMode: OrderMode.online,
      presenceService: presence,
      repository: repo,
      pdfService: _MockPdf(),
      stickerOrchestrator: _MockSticker(),
      salesOrderService: sales,
    );
    await provider.initialize();
    return provider;
  }

  setUp(() {
    presence = _MockPresence();
    sales = _MockSalesOrderService();
    repo = _MockRepository();
  });

  testWidgets('admin: batalkan order siap dikirim sampai status Dibatalkan',
      (tester) async {
    when(() => sales.cancelOrder(
          orderId: any(named: 'orderId'),
          reason: any(named: 'reason'),
        )).thenAnswer((_) async {});
    final provider = await buildProvider(admin: true);

    final order = <String, dynamic>{
      'id': 42,
      'receipt_no': 'REC-42',
      'delivery_status': 4,
      'items': <Map<String, dynamic>>[],
    };

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: order,
        orderMode: OrderMode.online,
        provider: provider,
      ),
    ));
    await tester.pump(); // post-frame selectOrder(widget.order)
    await tester.pump();

    expect(find.text('Batalkan Order'), findsOneWidget);

    await tester.ensureVisible(find.text('Batalkan Order'));
    await tester.tap(find.text('Batalkan Order'));
    await tester.pump(); // dialog muncul

    expect(find.text('Ya, Batalkan'), findsOneWidget);
    await tester.tap(find.text('Ya, Batalkan'));
    await tester.pump(); // tutup dialog + panggil service
    await tester.pump(const Duration(milliseconds: 50)); // state update
    await tester.pump(const Duration(milliseconds: 50)); // loadInitialOrders

    // Status live jadi 7: tombol hilang, badge Dibatalkan + alasan tampil.
    expect(find.text('Batalkan Order'), findsNothing);
    expect(find.text('Dibatalkan'), findsWidgets);
    expect(find.text('Alasan Pembatalan'), findsOneWidget);
    expect(find.text('Dibatalkan oleh pembeli'), findsOneWidget);
    verify(() => sales.cancelOrder(
          orderId: 42,
          reason: 'Dibatalkan oleh pembeli',
        )).called(1);
  });

  testWidgets('non-admin: tombol Batalkan Order tidak tampil', (tester) async {
    final provider = await buildProvider(admin: false);

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: <String, dynamic>{
          'id': 44,
          'receipt_no': 'REC-44',
          'delivery_status': 4,
          'items': <Map<String, dynamic>>[],
        },
        orderMode: OrderMode.online,
        provider: provider,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Batalkan Order'), findsNothing);
  });

  testWidgets('order sudah dikirim (status 3): tombol tidak tampil',
      (tester) async {
    final provider = await buildProvider(admin: true);

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: <String, dynamic>{
          'id': 45,
          'receipt_no': 'REC-45',
          'delivery_status': 3,
          'items': <Map<String, dynamic>>[],
        },
        orderMode: OrderMode.online,
        provider: provider,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Batalkan Order'), findsNothing);
  });
}
