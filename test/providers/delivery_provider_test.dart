import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/providers/delivery_provider.dart';
import 'package:sagansa/services/delivery_status_repository.dart';
import 'package:sagansa/services/payment_proof_pdf_service.dart';
import 'package:sagansa/services/presence_service.dart';
import 'package:sagansa/services/sticker_print_orchestrator.dart';

class _MockPresence extends Mock implements PresenceService {}
class _MockRepository extends Mock implements DeliveryStatusRepository {}
class _MockPdf extends Mock implements PaymentProofPdfService {}
class _MockSticker extends Mock implements StickerPrintOrchestrator {}

void main() {
  late DeliveryProvider provider;
  late _MockPresence mockPresence;
  late _MockRepository mockRepo;
  late _MockPdf mockPdf;
  late _MockSticker mockSticker;

  setUp(() {
    mockPresence = _MockPresence();
    mockRepo = _MockRepository();
    mockPdf = _MockPdf();
    mockSticker = _MockSticker();

    // Default stubs for initialize()
    when(() => mockRepo.loadAdminRole()).thenAnswer((_) async => false);
    when(() => mockRepo.loadCanManageSalesLink())
        .thenAnswer((_) async => false);
    when(() => mockRepo.loadPrintedStickers()).thenAnswer((_) async => {});

    provider = DeliveryProvider(
      orderMode: OrderMode.online,
      presenceService: mockPresence,
      repository: mockRepo,
      pdfService: mockPdf,
      stickerOrchestrator: mockSticker,
    );

    registerFallbackValue(OrderMode.online);
  });

  group('initial state', () {
    test('list state is empty and not loading', () {
      expect(provider.listState.isLoading, false);
      expect(provider.listState.orders, isEmpty);
      expect(provider.listState.error, isNull);
      expect(provider.listState.hasMore, true);
      expect(provider.listState.currentPage, 1);
    });

    test('form state has no selection', () {
      expect(provider.formState.hasSelection, false);
      expect(provider.formState.selectedOrder, isNull);
    });
  });

  group('initialize', () {
    test('memuat flag isAdmin dan canManageSalesLink', () async {
      when(() => mockRepo.loadAdminRole()).thenAnswer((_) async => false);
      when(() => mockRepo.loadCanManageSalesLink())
          .thenAnswer((_) async => true);
      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': true,
                'data': [],
                'meta': {'last_page': 1},
              });

      await provider.initialize();

      expect(provider.listState.isAdmin, false);
      expect(provider.listState.canManageSalesLink, true);
    });
  });

  group('loadInitialOrders', () {
    test('populates orders on success', () async {
      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': true,
                'data': [
                  {'id': 1, 'receipt_no': 'R1'},
                  {'id': 2, 'receipt_no': 'R2'},
                ],
                'meta': {'last_page': 1},
              });

      await provider.loadInitialOrders();

      expect(provider.listState.orders.length, 2);
      expect(provider.listState.isLoading, false);
      expect(provider.listState.hasMore, false); // page 1 of 1
      expect(provider.listState.error, isNull);
    });

    test('sets hasMore true when more pages exist', () async {
      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': true,
                'data': [{'id': 1}],
                'meta': {'last_page': 3},
              });

      await provider.loadInitialOrders();

      expect(provider.listState.hasMore, true); // page 1 of 3
    });

    test('sets error on exception', () async {
      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenThrow(Exception('network error'));

      await provider.loadInitialOrders();

      expect(provider.listState.isLoading, false);
      expect(provider.listState.error, isNotNull);
      expect(provider.listState.orders, isEmpty);
    });

    test('sets error when success is false', () async {
      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': false,
                'message': 'Unauthorized',
              });

      await provider.loadInitialOrders();

      expect(provider.listState.error, 'Unauthorized');
    });
  });

  group('loadMoreOrders', () {
    test('appends new orders to existing list', () async {
      // First load page 1.
      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': true,
                'data': [{'id': 1}],
                'meta': {'last_page': 2},
              });
      await provider.loadInitialOrders();

      // Then load page 2.
      when(() => mockPresence.getSalesOrders(
            page: 2,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': true,
                'data': [{'id': 2}, {'id': 3}],
                'meta': {'last_page': 2},
              });
      await provider.loadMoreOrders();

      expect(provider.listState.orders.length, 3);
      expect(provider.listState.currentPage, 2);
      expect(provider.listState.hasMore, false); // page 2 of 2
    });

    test('does not load when hasMore is false', () async {
      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': true,
                'data': [{'id': 1}],
                'meta': {'last_page': 1},
              });
      await provider.loadInitialOrders();

      // Should not call getSalesOrders again.
      await provider.loadMoreOrders();

      expect(provider.listState.orders.length, 1);
    });
  });

  group('searchOrder', () {
    test('throws when receipt is empty', () async {
      expect(
        () => provider.searchOrder(),
        throwsA(isA<Exception>()),
      );
    });

    test('selects order on successful search', () async {
      provider.receiptController.text = 'R123';
      when(() => mockPresence.searchSalesOrder(
            'R123',
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {
                'success': true,
                'data': {'id': 99, 'receipt_no': 'R123'},
              });

      await provider.searchOrder();

      expect(provider.formState.hasSelection, true);
      expect(provider.formState.selectedOrder?['id'], 99);
    });
  });

  group('selectOrder / clearSelection', () {
    test('selectOrder sets form state', () {
      provider.selectOrder({'id': 1, 'receipt_no': 'R1'});

      expect(provider.formState.hasSelection, true);
      expect(provider.formState.selectedOrder?['id'], 1);
    });

    test('clearSelection resets form state', () {
      provider.selectOrder({'id': 1});
      provider.clearSelection();

      expect(provider.formState.hasSelection, false);
      expect(provider.formState.selectedOrder, isNull);
    });
  });

  group('setStatus', () {
    test('updates selectedStatus in form state', () {
      provider.setStatus(6); // returned
      expect(provider.formState.selectedStatus, 6);

      provider.setStatus(3); // delivered
      expect(provider.formState.selectedStatus, 3);
    });
  });

  group('notifyListeners', () {
    test('notifies on loadInitialOrders state change', () async {
      var notifiedCount = 0;
      provider.addListener(() => notifiedCount++);

      when(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {'success': true, 'data': [], 'meta': {}});

      await provider.loadInitialOrders();

      expect(notifiedCount, greaterThan(0));
    });

    test('notifies on selectOrder', () {
      var notifiedCount = 0;
      provider.addListener(() => notifiedCount++);

      provider.selectOrder({'id': 1});

      expect(notifiedCount, greaterThan(0));
    });
  });
}
