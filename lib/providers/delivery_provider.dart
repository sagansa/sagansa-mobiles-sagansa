import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../models/enums/order_mode.dart';
import '../providers/printer_provider.dart';
import '../services/delivery_status_repository.dart';
import '../services/image_service.dart';
import '../services/payment_proof_pdf_service.dart';
import '../services/presence_service.dart';
import '../services/sticker_print_orchestrator.dart';

@immutable
class DeliveryListState {
  final List<Map<String, dynamic>> orders;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final String? error;
  final bool isLoadingSearch;
  final bool isPrintingPaymentProof;
  final bool isAdmin;
  final bool canManageSalesLink;
  final Set<int> printedStickers;

  const DeliveryListState({
    this.orders = const [],
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
    this.isLoadingSearch = false,
    this.isPrintingPaymentProof = false,
    this.isAdmin = false,
    this.canManageSalesLink = false,
    this.printedStickers = const {},
  });

  DeliveryListState copyWith({
    List<Map<String, dynamic>>? orders,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    String? error,
    bool? isLoadingSearch,
    bool? isPrintingPaymentProof,
    bool? isAdmin,
    bool? canManageSalesLink,
    Set<int>? printedStickers,
  }) {
    return DeliveryListState(
      orders: orders ?? this.orders,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isLoadingSearch: isLoadingSearch ?? this.isLoadingSearch,
      isPrintingPaymentProof:
          isPrintingPaymentProof ?? this.isPrintingPaymentProof,
      isAdmin: isAdmin ?? this.isAdmin,
      canManageSalesLink: canManageSalesLink ?? this.canManageSalesLink,
      printedStickers: printedStickers ?? this.printedStickers,
    );
  }

  List<Map<String, dynamic>> filteredOrders(
      bool isAdmin, OrderMode orderMode) {
    if (isAdmin || orderMode.isOnline) return orders;
    return orders
        .where((order) => order['payment_status']?.toString() != '3')
        .toList();
  }
}

@immutable
class DeliveryFormState {
  final Map<String, dynamic>? selectedOrder;
  final int selectedStatus;
  final bool isSubmitting;
  final bool isMarkingReady;
  final bool isPrintingSticker;
  final bool isUpdatingAssignment;
  final bool isPrintingPaymentProof;

  const DeliveryFormState({
    this.selectedOrder,
    this.selectedStatus = 3,
    this.isSubmitting = false,
    this.isMarkingReady = false,
    this.isPrintingSticker = false,
    this.isUpdatingAssignment = false,
    this.isPrintingPaymentProof = false,
  });

  DeliveryFormState copyWith({
    Map<String, dynamic>? selectedOrder,
    bool clearOrder = false,
    int? selectedStatus,
    bool? isSubmitting,
    bool? isMarkingReady,
    bool? isPrintingSticker,
    bool? isUpdatingAssignment,
    bool? isPrintingPaymentProof,
  }) {
    return DeliveryFormState(
      selectedOrder: clearOrder ? null : (selectedOrder ?? this.selectedOrder),
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isMarkingReady: isMarkingReady ?? this.isMarkingReady,
      isPrintingSticker: isPrintingSticker ?? this.isPrintingSticker,
      isUpdatingAssignment:
          isUpdatingAssignment ?? this.isUpdatingAssignment,
      isPrintingPaymentProof:
          isPrintingPaymentProof ?? this.isPrintingPaymentProof,
    );
  }

  bool get hasSelection => selectedOrder != null;
}

class DeliveryProvider extends ChangeNotifier {
  final PresenceService presenceService;
  final DeliveryStatusRepository repository;
  final PaymentProofPdfService pdfService;
  final StickerPrintOrchestrator stickerOrchestrator;
  final OrderMode orderMode;
  final ScrollController scrollController = ScrollController();

  DeliveryListState _listState = const DeliveryListState();
  DeliveryFormState _formState = const DeliveryFormState();

  final TextEditingController receiptController = TextEditingController();
  final TextEditingController receiverController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final List<File> imageFiles = [];

  DeliveryProvider({
    required this.orderMode,
    PresenceService? presenceService,
    DeliveryStatusRepository? repository,
    PaymentProofPdfService? pdfService,
    StickerPrintOrchestrator? stickerOrchestrator,
  })  : presenceService = presenceService ?? PresenceService(),
        repository = repository ?? DeliveryStatusRepository(),
        pdfService = pdfService ?? PaymentProofPdfService(),
        stickerOrchestrator =
            stickerOrchestrator ?? StickerPrintOrchestrator() {
    scrollController.addListener(_onScroll);
  }

  DeliveryListState get listState => _listState;
  DeliveryFormState get formState => _formState;
  List<Map<String, dynamic>> get filteredOrders =>
      _listState.filteredOrders(_listState.isAdmin, orderMode);

  bool isStickerPrinted(int orderId) =>
      _listState.printedStickers.contains(orderId);

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    receiptController.dispose();
    receiverController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 100) {
      loadMoreOrders();
    }
  }

  Future<void> initialize() async {
    final admin = await repository.loadAdminRole();
    final canManageSalesLink = await repository.loadCanManageSalesLink();
    final stickers = await repository.loadPrintedStickers();
    _listState = _listState.copyWith(
        isAdmin: admin,
        canManageSalesLink: canManageSalesLink,
        printedStickers: stickers);
    notifyListeners();
    loadInitialOrders();
  }

  Future<void> loadInitialOrders() async {
    if (_listState.isLoading) return;
    _listState = _listState.copyWith(
        isLoading: true, currentPage: 1, orders: [], hasMore: true, error: null);
    notifyListeners();

    try {
      final result = await presenceService.getSalesOrders(
        page: 1,
        perPage: 10,
        orderFor: orderMode.apiValue,
      );
      if (result['success'] == true) {
        final fetchedOrders =
            List<Map<String, dynamic>>.from(result['data'] ?? []);
        final meta = result['meta'] as Map<String, dynamic>? ?? {};
        final lastPage = meta['last_page'] ?? 1;
        _listState = _listState.copyWith(
          orders: fetchedOrders,
          hasMore: _listState.currentPage < lastPage,
          isLoading: false,
        );
      } else {
        _listState = _listState.copyWith(
          isLoading: false,
          error: result['message']?.toString() ?? 'Gagal memuat data',
        );
      }
    } catch (e) {
      _listState = _listState.copyWith(
        isLoading: false,
        error: 'Gagal memuat list order: $e',
      );
    }
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    if (_listState.isLoading || !_listState.hasMore) return;
    _listState = _listState.copyWith(isLoading: true);
    notifyListeners();

    final nextPage = _listState.currentPage + 1;

    try {
      final result = await presenceService.getSalesOrders(
        page: nextPage,
        perPage: 10,
        orderFor: orderMode.apiValue,
      );
      if (result['success'] == true) {
        final fetchedOrders =
            List<Map<String, dynamic>>.from(result['data'] ?? []);
        final meta = result['meta'] as Map<String, dynamic>? ?? {};
        final lastPage = meta['last_page'] ?? 1;
        _listState = _listState.copyWith(
          currentPage: nextPage,
          orders: [..._listState.orders, ...fetchedOrders],
          hasMore: nextPage < lastPage,
          isLoading: false,
        );
      }
    } catch (e) {
      _listState = _listState.copyWith(isLoading: false);
    }
    notifyListeners();
  }

  Future<void> searchOrder() async {
    final receiptNo = receiptController.text.trim();
    if (receiptNo.isEmpty) {
      throw Exception('Silakan masukkan nomor resi terlebih dahulu.');
    }

    _listState = _listState.copyWith(isLoadingSearch: true);
    notifyListeners();

    try {
      final result = await presenceService.searchSalesOrder(
        receiptNo,
        orderFor: orderMode.apiValue,
      );
      if (result['success'] == true && result['data'] != null) {
        final order = result['data'] as Map<String, dynamic>;
        _selectOrderInternal(order);
      } else {
        throw Exception(result['message'] ?? 'Order tidak ditemukan.');
      }
    } catch (e) {
      _listState = _listState.copyWith(isLoadingSearch: false);
      notifyListeners();
      rethrow;
    }

    _listState = _listState.copyWith(isLoadingSearch: false);
    notifyListeners();
  }

  /// Ganti item order terpilih (khusus admin). Setelah sukses, order
  /// terpilih diganti dengan data terbaru dari server sehingga detail
  /// langsung menampilkan items dan total yang baru.
  Future<void> updateOrderItems(List<Map<String, dynamic>> items) async {
    final order = _formState.selectedOrder;
    final orderId = int.tryParse(order?['id']?.toString() ?? '');
    if (order == null || orderId == null) {
      throw Exception('Tidak ada order terpilih.');
    }

    final result = await presenceService.updateSalesOrderItems(
      orderId: orderId,
      items: items,
    );

    if (result['success'] == true && result['data'] is Map<String, dynamic>) {
      _selectOrderInternal(result['data'] as Map<String, dynamic>);
      notifyListeners();
    } else {
      throw Exception(result['message'] ?? 'Gagal memperbarui rincian produk.');
    }
  }

  void selectOrder(Map<String, dynamic> order) {
    _selectOrderInternal(order);
    notifyListeners();
  }

  void _selectOrderInternal(Map<String, dynamic> order) {
    _clearFormInternal();
    _formState = _formState.copyWith(selectedOrder: order);
    if (order['received_by'] != null) {
      receiverController.text = order['received_by'] as String;
    }
    final currentStatus = order['delivery_status'] ?? 3;
    _formState = _formState.copyWith(
      selectedStatus: (currentStatus == 6) ? 6 : 3,
    );
  }

  void clearSelection() {
    _clearFormInternal();
    notifyListeners();
  }

  void clearSearch() {
    receiptController.clear();
    notifyListeners();
  }

  void _clearFormInternal() {
    _formState = const DeliveryFormState();
    imageFiles.clear();
    receiverController.clear();
    notesController.clear();
  }

  void setStatus(int status) {
    _formState = _formState.copyWith(selectedStatus: status);
    notifyListeners();
  }

  Future<void> addPhoto() async {
    final photo = await ImageService.pickAndResizeImage(
      source: ImageSource.camera,
    );
    if (photo != null) {
      imageFiles.add(photo);
      notifyListeners();
    }
  }

  void setPhotos(List<File> photos) {
    imageFiles
      ..clear()
      ..addAll(photos);
    notifyListeners();
  }

  void removePhotoAt(int index) {
    if (index < imageFiles.length) {
      imageFiles.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> submitDelivery({required VoidCallback onSuccess}) async {
    if (_formState.selectedOrder == null) return;

    final receiptNo = _formState.selectedOrder!['receipt_no']?.toString();
    if (orderMode.isOnline && (receiptNo == null || receiptNo.isEmpty)) {
      throw Exception('Nomor resi tidak tersedia pada order ini.');
    }

    if (_formState.selectedStatus == 3 && imageFiles.isEmpty) {
      throw Exception('Harap ambil foto bukti pengiriman terlebih dahulu.');
    }

    if (orderMode.isOnline &&
        _formState.selectedStatus == 3 &&
        receiverController.text.trim().isEmpty) {
      throw Exception('Harap isi nama penerima terlebih dahulu.');
    }

    if (_formState.selectedStatus == 6 &&
        notesController.text.trim().isEmpty) {
      throw Exception('Harap isi alasan barang dikembalikan pada catatan.');
    }

    _formState = _formState.copyWith(isSubmitting: true);
    notifyListeners();

    try {
      final isDirect = orderMode.isDirect;
      final orderId = isDirect
          ? int.tryParse(_formState.selectedOrder!['id'].toString())
          : null;

      final result = await presenceService.updateDeliveryStatus(
        receiptNo: isDirect ? null : receiptNo,
        orderId: orderId,
        imageFiles: imageFiles,
        receivedBy: _formState.selectedStatus == 6
            ? null
            : receiverController.text.trim(),
        deliveryStatus: _formState.selectedStatus,
        notes: _formState.selectedStatus == 6
            ? notesController.text.trim()
            : null,
      );

      if (result['success'] == true) {
        _clearFormInternal();
        notifyListeners();
        onSuccess();
        loadInitialOrders();
      } else {
        _formState = _formState.copyWith(isSubmitting: false);
        notifyListeners();
        throw Exception(
            result['message'] ?? 'Gagal memperbarui pengiriman.');
      }
    } catch (e) {
      _formState = _formState.copyWith(isSubmitting: false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markReadyToShip() async {
    if (_formState.selectedOrder == null) return;

    final orderId =
        int.tryParse(_formState.selectedOrder!['id'].toString());
    if (orderId == null) {
      throw Exception('ID order tidak tersedia.');
    }

    _formState = _formState.copyWith(isMarkingReady: true);
    notifyListeners();

    try {
      final result = await presenceService.markReadyToShip(
        orderId: orderId,
        orderFor: orderMode.apiValue,
      );

      if (result['success'] == true) {
        _formState = _formState.copyWith(
          selectedOrder: {
            ..._formState.selectedOrder!,
            'delivery_status':
                result['data']?['delivery_status'] ?? 4,
          },
          isMarkingReady: false,
        );
        notifyListeners();
        loadInitialOrders();
      } else {
        _formState = _formState.copyWith(isMarkingReady: false);
        notifyListeners();
        throw Exception(result['message'] ??
            'Gagal mengubah status menjadi siap dikirim.');
      }
    } catch (e) {
      _formState = _formState.copyWith(isMarkingReady: false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateAssignment({
    required int orderId,
    String? paymentStatus,
    int? storeId,
  }) async {
    _formState = _formState.copyWith(isUpdatingAssignment: true);
    notifyListeners();

    try {
      final result = await presenceService.assignSalesOrder(
        orderId: orderId,
        paymentStatus: paymentStatus,
        storeId: storeId,
      );

      if (result['success'] == true &&
          result['data'] is Map<String, dynamic>) {
        _selectOrderInternal(result['data'] as Map<String, dynamic>);
        _formState = _formState.copyWith(isUpdatingAssignment: false);
        notifyListeners();
        loadInitialOrders();
      } else {
        _formState = _formState.copyWith(isUpdatingAssignment: false);
        notifyListeners();
        throw Exception(
            result['message'] ?? 'Gagal menetapkan toko/status bayar.');
      }
    } catch (e) {
      _formState = _formState.copyWith(isUpdatingAssignment: false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> printAllPendingPaymentProofs() async {
    final allOrders = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;

    try {
      do {
        final result = await presenceService.getSalesOrders(
          page: page,
          perPage: 100,
          deliveryStatus: 1,
          hasPaymentProof: true,
          paymentProofPrinted: false,
          orderFor: orderMode.apiValue,
        );
        if (result['success'] != true) {
          throw Exception(
              result['message'] ?? 'Gagal memuat daftar pengiriman.');
        }

        final fetchedOrders =
            (result['data'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
        allOrders.addAll(fetchedOrders);

        final meta = result['meta'] as Map<String, dynamic>? ?? {};
        lastPage = meta['last_page'] ?? page;
        page += 1;
      } while (page <= lastPage);

      final unprinted =
          allOrders.where(_isUnprintedPaymentProof).toList();
      if (unprinted.isEmpty) {
        throw Exception(
            'Tidak ada bukti pembayaran yang belum dicetak.');
      }

      await _printPaymentProofsForOrders(unprinted);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> printPaymentProof(Map<String, dynamic> order) async {
    _formState = _formState.copyWith(isPrintingPaymentProof: true);
    notifyListeners();
    try {
      await pdfService.printPaymentProofs([order], orderMode, requirePending: false);
      _formState = _formState.copyWith(isPrintingPaymentProof: false);
      notifyListeners();
      loadInitialOrders();
    } catch (e) {
      _formState = _formState.copyWith(isPrintingPaymentProof: false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _printPaymentProofsForOrders(
      List<Map<String, dynamic>> orders) async {
    _listState = _listState.copyWith(isPrintingPaymentProof: true);
    notifyListeners();

    try {
      await pdfService.printPaymentProofs(orders, orderMode, requirePending: true);
      _listState = _listState.copyWith(isPrintingPaymentProof: false);
      notifyListeners();
      loadInitialOrders();
    } catch (e) {
      _listState = _listState.copyWith(isPrintingPaymentProof: false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> printSticker(
    Map<String, dynamic> order,
    PrinterProvider printerProvider,
  ) async {
    _formState = _formState.copyWith(isPrintingSticker: true);
    notifyListeners();

    try {
      final result =
          await stickerOrchestrator.printSticker(order, printerProvider);
      if (result.success && result.orderId != null) {
        await repository.savePrintedSticker(result.orderId!);
        _listState = _listState.copyWith(
          printedStickers: {
            ..._listState.printedStickers,
            result.orderId!
          },
        );
      }
      _formState = _formState.copyWith(isPrintingSticker: false);
      notifyListeners();
    } catch (e) {
      _formState = _formState.copyWith(isPrintingSticker: false);
      notifyListeners();
      rethrow;
    }
  }

  bool hasPaymentProof(Map<String, dynamic> order) {
    return order['image_payment_url'] != null &&
        order['image_payment_url'].toString().trim().isNotEmpty;
  }

  bool isPaymentProofPrinted(Map<String, dynamic> order) {
    return order['payment_proof_printed_at'] != null &&
        order['payment_proof_printed_at']
            .toString()
            .trim()
            .isNotEmpty;
  }

  bool _isUnprintedPaymentProof(Map<String, dynamic> order) {
    return order['delivery_status'] == 1 &&
        hasPaymentProof(order) &&
        !isPaymentProofPrinted(order);
  }

  String stickerPrintStatusText(Map<String, dynamic> order) {
    final orderId = int.tryParse(order['id']?.toString() ?? '') ?? -1;
    return isStickerPrinted(orderId)
        ? 'Resi sudah dicetak'
        : 'Resi belum dicetak';
  }

  String formatPrice(dynamic price) {
    if (price == null) return 'Rp 0';
    final parsed = double.tryParse(price.toString()) ?? 0;
    final formatter = parsed.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formatter';
  }
}
