import 'dart:io';

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
    when(() => mockRepo.loadDeliveryPhotoEditRole())
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

    test('memuat flag canEditDeliveryPhotos dari repository', () async {
      when(() => mockRepo.loadDeliveryPhotoEditRole())
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

      expect(provider.listState.canEditDeliveryPhotos, true);
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

  group('submitDelivery', () {
    test('berhasil mengupdate status delivery menjadi 3 dan mempertahankan selectedOrder', () async {
      provider.selectOrder({
        'id': 101,
        'receipt_no': 'REC-101',
        'delivery_status': 4,
      });
      provider.receiverController.text = 'Budi';
      provider.imageFiles.add(File('dummy.png'));

      when(() => mockPresence.updateDeliveryStatus(
            receiptNo: any(named: 'receiptNo'),
            orderId: any(named: 'orderId'),
            imageFiles: any(named: 'imageFiles'),
            receivedBy: any(named: 'receivedBy'),
            deliveryStatus: any(named: 'deliveryStatus'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => {
            'success': true,
            'message': 'Status pengiriman berhasil diperbarui.',
            'data': {
              'receipt_no': 'REC-101',
              'order_id': 101,
              'delivery_status': 3,
              'image_delivery_paths': ['images/Delivery/courier.jpg'],
              'image_delivery_urls': ['https://example.com/delivery.jpg'],
              'image_delivery_url': 'https://example.com/delivery.jpg',
            },
          });

      when(() => mockPresence.getSalesOrders(
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {'success': true, 'data': [], 'meta': {}});

      var successCalled = false;
      await provider.submitDelivery(onSuccess: () => successCalled = true);

      expect(successCalled, isTrue);
      expect(provider.formState.hasSelection, isTrue);
      expect(provider.formState.selectedOrder, isNotNull);
      expect(provider.formState.selectedOrder!['delivery_status'], 3);
      expect(provider.formState.selectedOrder!['received_by'], 'Budi');
      expect(provider.formState.selectedOrder!['image_delivery_url'],
          'https://example.com/delivery.jpg');
      // Paths harus ikut ditimpa dari respons server — bila stale, sheet
      // edit foto admin bisa menghapus file yang salah saat simpan.
      expect(provider.formState.selectedOrder!['image_delivery_paths'],
          ['images/Delivery/courier.jpg']);
      expect(provider.formState.isSubmitting, isFalse);
      expect(provider.imageFiles, isEmpty);
      expect(provider.receiverController.text, isEmpty);
    });

    test('submitDelivery menimpa image_delivery_paths dari respons',
        () async {
      provider.selectOrder({
        'id': 102,
        'receipt_no': 'REC-102',
        'delivery_status': 4,
        'image_delivery_paths': <String>[],
        'image_delivery_urls': <String>[],
      });
      provider.imageFiles.add(File('dummy.png'));
      provider.receiverController.text = 'Budi';

      when(() => mockPresence.updateDeliveryStatus(
            receiptNo: any(named: 'receiptNo'),
            orderId: any(named: 'orderId'),
            imageFiles: any(named: 'imageFiles'),
            receivedBy: any(named: 'receivedBy'),
            deliveryStatus: any(named: 'deliveryStatus'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => {
            'success': true,
            'message': 'Status pengiriman berhasil diperbarui.',
            'data': {
              'receipt_no': 'REC-102',
              'order_id': 102,
              'delivery_status': 3,
              'image_delivery_paths': ['images/Delivery/new1.jpg'],
              'image_delivery_urls': ['https://example.com/new1.jpg'],
              'image_delivery_url': 'https://example.com/new1.jpg',
            },
          });

      when(() => mockPresence.getSalesOrders(
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {'success': true, 'data': [], 'meta': {}});

      await provider.submitDelivery(onSuccess: () {});

      // paths lama kosong [] TIDAK boleh tersisa (stale) — harus diganti
      // paths terbaru dari server.
      expect(provider.formState.selectedOrder!['image_delivery_paths'],
          ['images/Delivery/new1.jpg']);
    });
  });

  group('updateDeliveryPhotos', () {
    test('sukses: service dipanggil, order terpilih diganti data terbaru',
        () async {
      provider.selectOrder({
        'id': 201,
        'receipt_no': 'REC-201',
        'delivery_status': 3,
        'image_delivery_urls': ['https://example.com/old.jpg'],
      });

      const updatedOrder = {
        'id': 201,
        'receipt_no': 'REC-201',
        'delivery_status': 3,
        'image_delivery_paths': ['images/Delivery/kept.jpg'],
        'image_delivery_urls': ['https://example.com/kept.jpg'],
        'image_delivery_url': 'https://example.com/kept.jpg',
      };

      when(() => mockPresence.updateDeliveryPhotos(
            orderId: any(named: 'orderId'),
            paths: any(named: 'paths'),
          )).thenAnswer((_) async => {
                'success': true,
                'message': 'Foto bukti pengiriman berhasil diperbarui.',
                'data': updatedOrder,
              });

      when(() => mockPresence.getSalesOrders(
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
            orderFor: any(named: 'orderFor'),
          )).thenAnswer((_) async => {'success': true, 'data': [], 'meta': {}});

      await provider.updateDeliveryPhotos(['images/Delivery/kept.jpg']);

      verify(() => mockPresence.updateDeliveryPhotos(
            orderId: 201,
            paths: ['images/Delivery/kept.jpg'],
          )).called(1);

      // Order terpilih terganti data terbaru dari server.
      expect(provider.formState.selectedOrder?['image_delivery_url'],
          'https://example.com/kept.jpg');
      expect(provider.formState.isUpdatingPhotos, isFalse);
      // List di-refresh setelah sukses.
      verify(() => mockPresence.getSalesOrders(
            page: 1,
            perPage: 10,
            orderFor: any(named: 'orderFor'),
          )).called(greaterThanOrEqualTo(1));
    });

    test('gagal (success false): throw dan loading flag pulih', () async {
      provider.selectOrder({'id': 202, 'delivery_status': 3});

      when(() => mockPresence.updateDeliveryPhotos(
            orderId: any(named: 'orderId'),
            paths: any(named: 'paths'),
          )).thenAnswer((_) async => {
                'success': false,
                'message': 'Hanya admin yang dapat mengubah foto pengiriman.',
              });

      await expectLater(
        provider.updateDeliveryPhotos(['images/Delivery/new.jpg']),
        throwsA(isA<Exception>()),
      );

      expect(provider.formState.isUpdatingPhotos, isFalse);
    });

    test('tanpa order terpilih: throw', () async {
      expect(
        () => provider.updateDeliveryPhotos(['images/Delivery/new.jpg']),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => mockPresence.updateDeliveryPhotos(
            orderId: any(named: 'orderId'),
            paths: any(named: 'paths'),
          ));
    });
  });

  group('updateOrderItems', () {
    test('mengirim items + shippingCost dan mengganti order terpilih',
        () async {
      provider.selectOrder({'id': 301, 'delivery_status': 1});

      const updatedOrder = {
        'id': 301,
        'delivery_status': 1,
        'total_price': 45000,
        'shipping_cost': 15000,
      };

      when(() => mockPresence.updateSalesOrderItems(
            orderId: 301,
            items: [
              {'product_id': 7, 'quantity': 3, 'unit_price': 10000},
            ],
            shippingCost: 15000,
          )).thenAnswer((_) async => {
            'success': true,
            'data': updatedOrder,
          });

      await provider.updateOrderItems(
        [
          {'product_id': 7, 'quantity': 3, 'unit_price': 10000},
        ],
        shippingCost: 15000,
      );

      verify(() => mockPresence.updateSalesOrderItems(
            orderId: 301,
            items: [
              {'product_id': 7, 'quantity': 3, 'unit_price': 10000},
            ],
            shippingCost: 15000,
          )).called(1);

      expect(provider.formState.selectedOrder?['shipping_cost'], 15000);
      expect(provider.formState.selectedOrder?['total_price'], 45000);
    });

    test('tanpa shippingCost: service menerima null (nilai lama server)', () async {
      provider.selectOrder({'id': 302, 'delivery_status': 1});

      when(() => mockPresence.updateSalesOrderItems(
            orderId: 302,
            items: [
              {'product_id': 8, 'quantity': 1, 'unit_price': 5000},
            ],
            shippingCost: null,
          )).thenAnswer((_) async => {
            'success': true,
            'data': {'id': 302, 'shipping_cost': 20000},
          });

      await provider.updateOrderItems([
        {'product_id': 8, 'quantity': 1, 'unit_price': 5000},
      ]);

      verify(() => mockPresence.updateSalesOrderItems(
            orderId: 302,
            items: [
              {'product_id': 8, 'quantity': 1, 'unit_price': 5000},
            ],
            shippingCost: null,
          )).called(1);
    });

    test('tanpa order terpilih: throw', () async {
      expect(
        () => provider.updateOrderItems([
          {'product_id': 1, 'quantity': 1, 'unit_price': 1000},
        ]),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => mockPresence.updateSalesOrderItems(
            orderId: any(named: 'orderId'),
            items: any(named: 'items'),
            shippingCost: any(named: 'shippingCost'),
          ));
    });
  });
}
