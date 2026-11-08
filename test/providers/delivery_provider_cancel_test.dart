import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/providers/delivery_provider.dart';
import 'package:sagansa/services/delivery_status_repository.dart';
import 'package:sagansa/services/payment_proof_pdf_service.dart';
import 'package:sagansa/services/presence_service.dart';
import 'package:sagansa/services/sales_order_service.dart';
import 'package:sagansa/services/sticker_print_orchestrator.dart';

class _MockPresence extends Mock implements PresenceService {}

class _MockRepository extends Mock implements DeliveryStatusRepository {}

class _MockPdf extends Mock implements PaymentProofPdfService {}

class _MockSticker extends Mock implements StickerPrintOrchestrator {}

class _MockSalesOrderService extends Mock implements SalesOrderService {}

/// cancelOrder: sukses → selectedOrder status 7 + notes terisi + list
/// refresh; gagal → error dilempar dan isCancelling kembali false.
void main() {
  late _MockPresence presence;
  late _MockSalesOrderService sales;
  late DeliveryProvider provider;

  setUp(() {
    presence = _MockPresence();
    sales = _MockSalesOrderService();

    final repo = _MockRepository();
    when(() => repo.loadAdminRole()).thenAnswer((_) async => true);
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

    provider = DeliveryProvider(
      orderMode: OrderMode.online,
      presenceService: presence,
      repository: repo,
      pdfService: _MockPdf(),
      stickerOrchestrator: _MockSticker(),
      salesOrderService: sales,
    );
  });

  test('cancelOrder sukses mengubah selectedOrder ke status 7 + notes',
      () async {
    when(() => sales.cancelOrder(
          orderId: any(named: 'orderId'),
          reason: any(named: 'reason'),
        )).thenAnswer((_) async {});

    provider.selectOrder(<String, dynamic>{
      'id': 42,
      'receipt_no': 'REC-42',
      'delivery_status': 4,
    });

    await provider.cancelOrder('Dibatalkan oleh pembeli');

    expect(provider.formState.selectedOrder!['delivery_status'], 7);
    expect(provider.formState.selectedOrder!['notes'],
        'Dibatalkan oleh pembeli');
    expect(provider.formState.isCancelling, isFalse);
    verify(() => sales.cancelOrder(
          orderId: 42,
          reason: 'Dibatalkan oleh pembeli',
        )).called(1);
  });

  test('cancelOrder gagal melempar error dan isCancelling kembali false',
      () async {
    when(() => sales.cancelOrder(
          orderId: any(named: 'orderId'),
          reason: any(named: 'reason'),
        )).thenThrow(Exception('Order sudah dibatalkan sebelumnya.'));

    provider.selectOrder(<String, dynamic>{
      'id': 43,
      'receipt_no': 'REC-43',
      'delivery_status': 4,
    });

    await expectLater(
      provider.cancelOrder('Dibatalkan oleh pembeli'),
      throwsA(isA<Exception>()),
    );

    expect(provider.formState.isCancelling, isFalse);
    // selectedOrder tidak berubah — tetap status lama.
    expect(provider.formState.selectedOrder!['delivery_status'], 4);
  });
}
