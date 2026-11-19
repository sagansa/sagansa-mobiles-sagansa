import '../services/image_service.dart';
import '../utils/supplier_name.dart';
import 'enums/procurement_item_status.dart';

/// Parse nilai numerik yang bisa datang sebagai `int`, `double`, maupun
/// `String` dari API (tergantung driver DB/MySQL). Mencegah error
/// `String is not a subtype of type int` pada `fromJson`.
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

int? _toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

class ProcurementProduct {
  final int id;
  final String name;
  final int? unitId;
  final int? paymentTypeId;
  final String unitName;

  ProcurementProduct({
    required this.id,
    required this.name,
    this.unitId,
    this.paymentTypeId,
    required this.unitName,
  });

  factory ProcurementProduct.fromJson(Map<String, dynamic> json) {
    return ProcurementProduct(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      unitId: _toIntOrNull(json['unit_id']),
      paymentTypeId: _toIntOrNull(json['payment_type_id']),
      unitName: (json['unit']?['unit'] ?? '').toString(),
    );
  }
}

class DetailRequestItem {
  final int id;
  final int productId;
  final double quantityPlan;
  final String status;
  final int? paymentTypeId;
  final String productName;
  final String unitName;

  DetailRequestItem({
    required this.id,
    required this.productId,
    required this.quantityPlan,
    required this.status,
    this.paymentTypeId,
    required this.productName,
    required this.unitName,
  });

  String get statusText {
    switch (status) {
      case '1':
        return 'Process';
      case '2':
        return 'Done';
      case '3':
        return 'Rejected';
      case '4':
        return 'Approved';
      case '5':
        return 'Not Valid';
      case '6':
        return 'Not Used';
      default:
        return 'Unknown';
    }
  }

  factory DetailRequestItem.fromJson(Map<String, dynamic> json) {
    return DetailRequestItem(
      id: _toInt(json['id']),
      productId: _toInt(json['product_id']),
      quantityPlan:
          double.tryParse(json['quantity_plan']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? '1',
      paymentTypeId: _toIntOrNull(json['payment_type_id']),
      productName: (json['product']?['name'] ?? '').toString(),
      unitName: (json['product']?['unit']?['unit'] ?? '').toString(),
    );
  }
}

/// Extension untuk mapping `DetailRequestItem.status` (String) ke enum.
extension DetailRequestItemStatusX on DetailRequestItem {
  /// Status sebagai enum ter-type-safe.
  ProcurementItemStatus get statusEnum => ProcurementItemStatus.fromApi(status);
}

class DetailInvoiceItem {
  final int id;
  final int invoicePurchaseId;
  final int? detailRequestId;
  final double quantityProduct;
  final double? quantityInvoice;
  final double subtotalInvoice;
  final String? status;
  final String productName;
  final String unitName;

  /// Riwayat harga beli terakhir (maksimal 5) — hanya diisi untuk admin.
  final List<LastPurchasePrice> lastPurchasePrices;

  DetailInvoiceItem({
    required this.id,
    required this.invoicePurchaseId,
    this.detailRequestId,
    required this.quantityProduct,
    this.quantityInvoice,
    required this.subtotalInvoice,
    this.status,
    required this.productName,
    required this.unitName,
    this.lastPurchasePrices = const [],
  });

  double get unitPrice {
    if (quantityProduct == 0) return 0;
    return subtotalInvoice / quantityProduct;
  }

  String get statusText {
    switch (status) {
      case '3':
        return 'Need Adjustment';
      default:
        return 'Processed';
    }
  }

  factory DetailInvoiceItem.fromJson(Map<String, dynamic> json) {
    final detailRequest = json['detail_request'] is Map
        ? Map<String, dynamic>.from(json['detail_request'] as Map)
        : null;
    String productName = '';
    String unitName = '';

    if (detailRequest != null) {
      final product = detailRequest['product'] is Map
          ? Map<String, dynamic>.from(detailRequest['product'] as Map)
          : null;
      if (product != null) {
        productName = (product['name'] ?? '').toString();
        final unit = product['unit'] is Map
            ? Map<String, dynamic>.from(product['unit'] as Map)
            : null;
        unitName = (unit?['unit'] ?? '').toString();
      }
    }

    final rawPrices = json['last_purchase_price'];
    final prices = rawPrices is List
        ? rawPrices
            .whereType<Map>()
            .map(
                (e) => LastPurchasePrice.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.hasData)
            .toList()
        : rawPrices is Map
            ? [LastPurchasePrice.fromJson(Map<String, dynamic>.from(rawPrices))]
            : <LastPurchasePrice>[];

    return DetailInvoiceItem(
      id: _toInt(json['id']),
      invoicePurchaseId: _toInt(json['invoice_purchase_id']),
      detailRequestId: _toIntOrNull(json['detail_request_id']),
      quantityProduct:
          double.tryParse(json['quantity_product']?.toString() ?? '0') ?? 0.0,
      quantityInvoice: json['quantity_invoice'] != null
          ? double.tryParse(json['quantity_invoice'].toString())
          : null,
      subtotalInvoice:
          double.tryParse(json['subtotal_invoice']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString(),
      productName: productName,
      unitName: unitName,
      lastPurchasePrices: prices,
    );
  }
}

/// Harga beli terakhir sebuah product (lintas supplier).
///
/// Dipakai admin untuk evaluasi harga di invoice detail.
class LastPurchasePrice {
  final int unitPrice;
  final String? supplierName;
  final DateTime? date;

  const LastPurchasePrice({
    required this.unitPrice,
    this.supplierName,
    this.date,
  });

  factory LastPurchasePrice.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LastPurchasePrice(unitPrice: 0);
    return LastPurchasePrice(
      unitPrice: _toInt(json['unit_price']),
      supplierName: json['supplier_name'] == null
          ? null
          : formatSupplierName(json['supplier_name'].toString()),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
    );
  }

  bool get hasData => unitPrice > 0;
}

class ClosingStoreRef {
  final int id;
  final String date;

  ClosingStoreRef({required this.id, required this.date});

  factory ClosingStoreRef.fromJson(Map<String, dynamic> json) {
    return ClosingStoreRef(
      id: _toInt(json['id']),
      date: (json['date'] ?? '').toString(),
    );
  }
}

class InvoicePurchase {
  final int id;
  final int? paymentTypeId;
  final int storeId;
  final int? supplierId;
  final String date;
  final int taxes;
  final int discounts;
  final int totalPrice;
  final String? notes;
  final int createdById;
  final String paymentStatus;
  final String orderStatus;
  final String storeName;
  final String? supplierName;
  final String createdByName;
  final List<DetailInvoiceItem> detailInvoices;
  final String? image;
  String? get imageUrl => ImageService.buildUrl(image);

  /// Data pembayaran supplier — dipakai kartu "Pembayaran Transfer" di
  /// invoice detail (tipe transfer = paymentTypeId 1).
  final bool supplierHasQris;
  final String? supplierBankName;
  final String? supplierBankAccountNo;
  final String? supplierBankAccountName;
  final int? salesOrderId;
  final SalesOrderSummary? salesOrder;
  final List<ClosingStoreRef> closingStores;

  InvoicePurchase({
    required this.id,
    this.paymentTypeId,
    required this.storeId,
    this.supplierId,
    required this.date,
    this.taxes = 0,
    this.discounts = 0,
    this.totalPrice = 0,
    this.notes,
    required this.createdById,
    this.paymentStatus = '1',
    this.orderStatus = '1',
    required this.storeName,
    this.supplierName,
    this.createdByName = '',
    this.detailInvoices = const [],
    this.image,
    this.supplierHasQris = false,
    this.supplierBankName,
    this.supplierBankAccountNo,
    this.supplierBankAccountName,
    this.salesOrderId,
    this.salesOrder,
    this.closingStores = const [],
  });

  bool get isTransfer => paymentTypeId == 1;

  bool get isCash => paymentTypeId == 2;

  bool get hasSupplierBankAccount =>
      (supplierBankAccountNo ?? '').isNotEmpty &&
      (supplierBankAccountName ?? '').isNotEmpty;

  String get paymentStatusText {
    switch (paymentStatus) {
      case '1':
        return 'Belum Dibayar';
      case '2':
        return 'Sudah Dibayar';
      case '3':
        return 'Tidak Valid';
      default:
        return 'Unknown';
    }
  }

  String get orderStatusText {
    switch (orderStatus) {
      case '1':
        return 'Belum Diterima';
      case '2':
        return 'Sudah Diterima';
      case '3':
        return 'Dikembalikan';
      default:
        return 'Unknown';
    }
  }

  String get paymentTypeText {
    return paymentTypeId == 2 ? 'Tunai' : 'Transfer';
  }

  factory InvoicePurchase.fromJson(Map<String, dynamic> json) {
    final list = json['detail_invoices'] as List? ?? [];
    final List<DetailInvoiceItem> items =
        list.map((i) => DetailInvoiceItem.fromJson(i)).toList();

    return InvoicePurchase(
      id: _toInt(json['id']),
      paymentTypeId: _toIntOrNull(json['payment_type_id']),
      storeId: _toInt(json['store_id']),
      supplierId: _toIntOrNull(json['supplier_id']),
      date: (json['date'] ?? '').toString(),
      taxes: _toInt(json['taxes']),
      discounts: _toInt(json['discounts']),
      totalPrice: _toInt(json['total_price']),
      notes: json['notes']?.toString(),
      createdById: _toInt(json['created_by_id']),
      paymentStatus: json['payment_status']?.toString() ?? '1',
      orderStatus: json['order_status']?.toString() ?? '1',
      storeName:
          (json['store']?['nickname'] ?? json['store']?['name'] ?? 'Toko')
              .toString(),
      supplierName: json['supplier']?['name'] == null
          ? null
          : formatSupplierName(json['supplier']!['name'].toString()),
      supplierHasQris: (json['supplier']?['qris']?.toString() ?? '').isNotEmpty,
      supplierBankName: json['supplier']?['bank']?['name']?.toString(),
      supplierBankAccountNo: json['supplier']?['bank_account_no']?.toString(),
      supplierBankAccountName:
          json['supplier']?['bank_account_name']?.toString(),
      createdByName: (json['created_by']?['name'] ?? '').toString(),
      detailInvoices: items,
      image: json['image']?.toString(),
      salesOrderId: _toIntOrNull(json['sales_order_id']),
      salesOrder: json['sales_order'] == null
          ? null
          : SalesOrderSummary.fromJson(
              Map<String, dynamic>.from(json['sales_order'])),
      closingStores: (json['closing_stores'] as List? ?? [])
          .map((e) => ClosingStoreRef.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class RequestPurchase {
  final int id;
  final int storeId;
  final String storeName;
  final String date;
  final int userId;
  final String userName;
  final List<DetailRequestItem> detailRequests;

  /// Jumlah item request yang sudah memiliki DetailInvoice (dari
  /// withCount endpoint show). Dipakai untuk menonaktifkan aksi hapus
  /// request yang sudah menjadi invoice (guard backend destroyRequest).
  final int invoicedItemsCount;

  RequestPurchase({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.date,
    required this.userId,
    required this.userName,
    required this.detailRequests,
    this.invoicedItemsCount = 0,
  });

  /// True bila minimal satu item request sudah masuk ke invoice pembelian.
  bool get hasInvoices => invoicedItemsCount > 0;

  String get overallStatusText {
    if (detailRequests.isEmpty) return 'No Items';
    if (detailRequests.any((item) => item.statusEnum.isPending)) {
      return ProcurementItemStatus.pending.displayLabel;
    }
    if (detailRequests.every((item) => item.statusEnum.isRejected)) {
      return ProcurementItemStatus.rejected.displayLabel;
    }
    if (detailRequests.any((item) => item.statusEnum.isPartiallyApproved)) {
      return ProcurementItemStatus.partiallyApproved.displayLabel;
    }
    if (detailRequests.every((item) => item.statusEnum.isDone)) {
      return ProcurementItemStatus.done.displayLabel;
    }
    return 'Processed';
  }

  factory RequestPurchase.fromJson(Map<String, dynamic> json) {
    final list = json['detail_requests'] as List? ?? [];
    final List<DetailRequestItem> items =
        list.map((i) => DetailRequestItem.fromJson(i)).toList();

    return RequestPurchase(
      id: _toInt(json['id']),
      storeId: _toInt(json['store_id']),
      storeName:
          (json['store']?['nickname'] ?? json['store']?['name'] ?? 'Toko')
              .toString(),
      date: (json['date'] ?? '').toString(),
      userId: _toInt(json['user_id']),
      userName: (json['user']?['name'] ?? '').toString(),
      detailRequests: items,
      invoicedItemsCount: _toInt(json['invoiced_items_count']),
    );
  }
}

class PaginatedResult<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

class PaymentReceipt {
  final int id;
  final String paymentFor;
  final int totalAmount;
  final int transferAmount;
  final int? supplierId;
  final String? notes;
  final String? image;
  String? get imageUrl => ImageService.buildUrl(image);
  final String? imageAdjust;
  String? get imageAdjustUrl => ImageService.buildUrl(imageAdjust);
  final String createdAt;
  final String? supplierName;
  final List<InvoicePurchase> invoicePurchases;
  final List<FuelServiceItem> fuelServices;
  final List<DailySalaryReceiptItem> dailySalaries;

  PaymentReceipt({
    required this.id,
    this.paymentFor = '3',
    this.totalAmount = 0,
    this.transferAmount = 0,
    this.supplierId,
    this.notes,
    this.image,
    this.imageAdjust,
    required this.createdAt,
    this.supplierName,
    this.invoicePurchases = const [],
    this.fuelServices = const [],
    this.dailySalaries = const [],
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) {
    final list = json['invoice_purchases'] as List? ?? [];
    final List<InvoicePurchase> invoices =
        list.map((i) => InvoicePurchase.fromJson(i)).toList();

    final fuelList = json['fuel_services'] as List? ?? [];
    final List<FuelServiceItem> fuelServices = fuelList
        .map((i) => FuelServiceItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final salaryList = json['daily_salaries'] as List? ?? [];
    final List<DailySalaryReceiptItem> dailySalaries = salaryList
        .map((i) => DailySalaryReceiptItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return PaymentReceipt(
      id: _toInt(json['id']),
      paymentFor: json['payment_for']?.toString() ?? '3',
      totalAmount: _toInt(json['total_amount']),
      transferAmount: _toInt(json['transfer_amount']),
      supplierId: _toIntOrNull(json['supplier_id']),
      notes: json['notes']?.toString(),
      image: json['image']?.toString(),
      imageAdjust: json['image_adjust']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      supplierName: json['supplier']?['name'] == null
          ? null
          : formatSupplierName(json['supplier']!['name'].toString()),
      invoicePurchases: invoices,
      fuelServices: fuelServices,
      dailySalaries: dailySalaries,
    );
  }
}

/// Representasi ringkas satu item fuel/service yang tercantum dalam sebuah
/// [PaymentReceipt] (payment_for == '1'). Field-field ini sama dengan yang
/// dipakai untuk merender list fuel service (fuel_service_page.dart).
class FuelServiceItem {
  final int id;
  final int fuelService; // 1 = Fuel, 2 = Service
  final int amount;
  final String date;
  final String? vehicleRegister;
  final String km;
  final String? createdByName;
  final int? supplierId;
  final String? supplierName;
  final String? supplierBankName;
  final String? supplierBankAccountNo;
  final String? supplierBankAccountName;
  final String? supplierQris;

  FuelServiceItem({
    required this.id,
    this.fuelService = 1,
    this.amount = 0,
    this.date = '',
    this.vehicleRegister,
    this.km = '',
    this.createdByName,
    this.supplierId,
    this.supplierName,
    this.supplierBankName,
    this.supplierBankAccountNo,
    this.supplierBankAccountName,
    this.supplierQris,
  });

  String get typeLabel => fuelService == 1 ? 'Fuel' : 'Service';

  factory FuelServiceItem.fromJson(Map<String, dynamic> json) {
    return FuelServiceItem(
      id: _toInt(json['id']),
      fuelService: _toIntOrNull(json['fuel_service']) ?? 1,
      amount: _toInt(json['amount']),
      date: json['date']?.toString() ?? '',
      vehicleRegister: json['vehicle']?['no_register']?.toString(),
      km: json['km']?.toString() ?? '',
      createdByName: json['created_by']?['name']?.toString(),
      supplierId: _toIntOrNull(json['supplier']?['id']),
      supplierName: json['supplier']?['name'] == null
          ? null
          : formatSupplierName(json['supplier']!['name'].toString()),
      supplierBankName: json['supplier']?['bank']?['name']?.toString(),
      supplierBankAccountNo: json['supplier']?['bank_account_no']?.toString(),
      supplierBankAccountName:
          json['supplier']?['bank_account_name']?.toString(),
      supplierQris: json['supplier']?['qris']?.toString(),
    );
  }
}

/// Representasi ringkas satu daily salary yang tercantum dalam sebuah
/// [PaymentReceipt] (payment_for == '2'). Cermin [FuelServiceItem].
class DailySalaryReceiptItem {
  final int id;
  final int amount;
  final String date;
  final String? createdByName;
  final int? createdById;

  DailySalaryReceiptItem({
    required this.id,
    this.amount = 0,
    this.date = '',
    this.createdByName,
    this.createdById,
  });

  factory DailySalaryReceiptItem.fromJson(Map<String, dynamic> json) {
    return DailySalaryReceiptItem(
      id: _toInt(json['id']),
      amount: _toInt(json['amount']),
      date: json['date']?.toString() ?? '',
      createdByName: json['created_by']?['name']?.toString(),
      createdById: _toIntOrNull(json['created_by']?['id']),
    );
  }
}

/// Ringkasan penjualan terkait invoice (dari showInvoice).
class SalesOrderSummary {
  final int id;
  final int forType;
  final String? receiptNo;
  final String storeName;
  final String? deliveryDate;
  final int totalPrice;

  const SalesOrderSummary({
    required this.id,
    required this.forType,
    this.receiptNo,
    required this.storeName,
    this.deliveryDate,
    this.totalPrice = 0,
  });

  String get typeName => switch (forType) {
        1 => 'DIRECT',
        2 => 'EMPLOYEE',
        3 => 'ONLINE',
        _ => '-',
      };

  String get label =>
      receiptNo == null || receiptNo!.isEmpty ? 'ORDER #$id' : receiptNo!;

  factory SalesOrderSummary.fromJson(Map<String, dynamic> json) {
    return SalesOrderSummary(
      id: int.tryParse('${json['id']}') ?? 0,
      forType: int.tryParse('${json['for']}') ?? 0,
      receiptNo: json['receipt_no']?.toString(),
      storeName: (json['store']?['nickname'] ??
              json['store']?['name'] ??
              json['store_name'] ??
              '-')
          .toString(),
      deliveryDate: json['delivery_date']?.toString(),
      totalPrice: int.tryParse('${json['total_price'] ?? 0}') ?? 0,
    );
  }
}

/// Kandidat penjualan (endpoint link-candidates).
class SalesOrderCandidate {
  final int id;
  final int forType;
  final String? receiptNo;
  final String storeName;
  final String? deliveryDate;
  final int totalPrice;
  final String buyerName;
  final String buyerPhone;
  final String buyerAddress;

  const SalesOrderCandidate({
    required this.id,
    required this.forType,
    this.receiptNo,
    required this.storeName,
    this.deliveryDate,
    this.totalPrice = 0,
    this.buyerName = '-',
    this.buyerPhone = '',
    this.buyerAddress = '',
  });

  String get typeName => switch (forType) {
        1 => 'DIRECT',
        2 => 'EMPLOYEE',
        3 => 'ONLINE',
        _ => '-',
      };

  String get label =>
      receiptNo == null || receiptNo!.isEmpty ? 'ORDER #$id' : receiptNo!;

  factory SalesOrderCandidate.fromJson(Map<String, dynamic> json) {
    return SalesOrderCandidate(
      id: int.tryParse('${json['id']}') ?? 0,
      forType: int.tryParse('${json['for']}') ?? 0,
      receiptNo: json['receipt_no']?.toString(),
      storeName: (json['store_name'] ?? '-').toString(),
      deliveryDate: json['delivery_date']?.toString(),
      totalPrice: int.tryParse('${json['total_price'] ?? 0}') ?? 0,
      buyerName: (json['buyer_name'] ?? '-').toString(),
      buyerPhone: (json['buyer_phone'] ?? '').toString(),
      buyerAddress: (json['buyer_address'] ?? '').toString(),
    );
  }
}

/// Baris ringan invoice pembelian dari endpoint purchase-invoices /
/// invoices/link-candidates (bentuk row identik di kedua endpoint).
class InvoiceLinkCandidate {
  final int id;
  final String supplierName;
  final int totalPrice;
  final String paymentStatus;
  final String orderStatus;
  final String? date;

  const InvoiceLinkCandidate({
    required this.id,
    this.supplierName = '-',
    this.totalPrice = 0,
    this.paymentStatus = '1',
    this.orderStatus = '1',
    this.date,
  });

  /// Kaitan hanya bisa diubah selama invoice draft (guard backend
  /// updateInvoice: payment_status '1').
  bool get isDraft => paymentStatus == '1';

  String get paymentLabel => switch (paymentStatus) {
        '1' => 'Belum Dibayar',
        '2' => 'Sudah Dibayar',
        '3' => 'Tidak Valid',
        _ => '-',
      };

  factory InvoiceLinkCandidate.fromJson(Map<String, dynamic> json) {
    return InvoiceLinkCandidate(
      id: int.tryParse('${json['id']}') ?? 0,
      supplierName:
          formatSupplierName((json['supplier_name'] ?? '-').toString()),
      totalPrice: int.tryParse('${json['total_price'] ?? 0}') ?? 0,
      paymentStatus: (json['payment_status'] ?? '1').toString(),
      orderStatus: (json['order_status'] ?? '1').toString(),
      date: json['date']?.toString(),
    );
  }
}

/// Pembelian terakhir sebuah bahan baku — per store saat filter toko aktif,
/// lintas store saat mode "Semua Toko" (storeName terisi).
class ProductLastPurchase {
  final DateTime? date;
  final double quantity;
  final int unitPrice;
  final String? supplierName;
  final int? storeId;
  final String? storeName;

  const ProductLastPurchase({
    this.date,
    this.quantity = 0,
    required this.unitPrice,
    this.supplierName,
    this.storeId,
    this.storeName,
  });

  factory ProductLastPurchase.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProductLastPurchase(unitPrice: 0);
    return ProductLastPurchase(
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      quantity: double.tryParse('${json['quantity'] ?? 0}') ?? 0,
      unitPrice: _toInt(json['unit_price']),
      supplierName: json['supplier_name'] == null
          ? null
          : formatSupplierName(json['supplier_name'].toString()),
      storeId: _toIntOrNull(json['store_id']),
      storeName: json['store_name']?.toString(),
    );
  }

  bool get hasData => unitPrice > 0;
}

/// Bahan baku yang sedang terikat di invoice belum lunas
/// (payment_status '1') untuk store terpilih / semua toko.
class ProductInProcess {
  final double quantity;
  final int invoiceCount;
  final DateTime? oldestInvoiceDate;

  const ProductInProcess({
    required this.quantity,
    required this.invoiceCount,
    this.oldestInvoiceDate,
  });

  factory ProductInProcess.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProductInProcess(quantity: 0, invoiceCount: 0);
    return ProductInProcess(
      quantity: double.tryParse('${json['quantity'] ?? 0}') ?? 0,
      invoiceCount: _toInt(json['invoice_count']),
      oldestInvoiceDate: json['oldest_invoice_date'] != null
          ? DateTime.tryParse(json['oldest_invoice_date'].toString())
          : null,
    );
  }

  bool get hasData => invoiceCount > 0;
}

/// Baris data halaman "Info Beli Bahan Baku" (admin): bahan baku +
/// pembelian terakhir + qty dalam invoice belum lunas.
class ProductPurchaseInfo {
  final int id;
  final String name;
  final String unitName;
  final ProductLastPurchase? lastPurchase;

  /// Hingga 5 pembelian terbaru (terbaru dulu) — ditampilkan di kartu list.
  final List<ProductLastPurchase> recentPurchases;
  final ProductInProcess? inProcess;

  const ProductPurchaseInfo({
    required this.id,
    required this.name,
    required this.unitName,
    this.lastPurchase,
    this.recentPurchases = const [],
    this.inProcess,
  });

  factory ProductPurchaseInfo.fromJson(Map<String, dynamic> json) {
    return ProductPurchaseInfo(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      unitName: (json['unit']?['unit'] ?? '').toString(),
      lastPurchase: json['last_purchase'] == null
          ? null
          : ProductLastPurchase.fromJson(
              Map<String, dynamic>.from(json['last_purchase'])),
      recentPurchases: (json['recent_purchases'] as List<dynamic>? ?? [])
          .map((e) => ProductLastPurchase.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      inProcess: json['in_process'] == null
          ? null
          : ProductInProcess.fromJson(
              Map<String, dynamic>.from(json['in_process'])),
    );
  }
}

/// Baris riwayat pembelian satu bahan baku (endpoint detail).
class ProductPurchaseHistoryItem {
  final int invoiceId;
  final DateTime? date;
  final double quantity;
  final int unitPrice;
  final int subtotal;
  final String? supplierName;
  final int? storeId;
  final String? storeName;
  final String paymentStatus;
  final String orderStatus;

  const ProductPurchaseHistoryItem({
    required this.invoiceId,
    this.date,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.supplierName,
    this.storeId,
    this.storeName,
    this.paymentStatus = '1',
    this.orderStatus = '1',
  });

  String get paymentLabel => switch (paymentStatus) {
        '1' => 'Belum Dibayar',
        '2' => 'Lunas',
        '3' => 'Tidak Valid',
        _ => '-',
      };

  factory ProductPurchaseHistoryItem.fromJson(Map<String, dynamic> json) {
    return ProductPurchaseHistoryItem(
      invoiceId: _toInt(json['invoice_id']),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      quantity: double.tryParse('${json['quantity'] ?? 0}') ?? 0,
      unitPrice: _toInt(json['unit_price']),
      subtotal: _toInt(json['subtotal']),
      supplierName: json['supplier_name'] == null
          ? null
          : formatSupplierName(json['supplier_name'].toString()),
      storeId: _toIntOrNull(json['store_id']),
      storeName: json['store_name']?.toString(),
      paymentStatus: (json['payment_status'] ?? '1').toString(),
      orderStatus: (json['order_status'] ?? '1').toString(),
    );
  }
}

/// Ringkasan statistik pembelian satu bahan baku untuk analisa.
class ProductPurchaseSummary {
  final int totalInvoices;
  final double totalQuantity;
  final int totalValue;
  final int minUnitPrice;
  final int maxUnitPrice;
  final int avgUnitPrice;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const ProductPurchaseSummary({
    required this.totalInvoices,
    required this.totalQuantity,
    required this.totalValue,
    required this.minUnitPrice,
    required this.maxUnitPrice,
    required this.avgUnitPrice,
    this.firstDate,
    this.lastDate,
  });

  factory ProductPurchaseSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ProductPurchaseSummary(
        totalInvoices: 0,
        totalQuantity: 0,
        totalValue: 0,
        minUnitPrice: 0,
        maxUnitPrice: 0,
        avgUnitPrice: 0,
      );
    }
    return ProductPurchaseSummary(
      totalInvoices: _toInt(json['total_invoices']),
      totalQuantity: double.tryParse('${json['total_quantity'] ?? 0}') ?? 0,
      totalValue: _toInt(json['total_value']),
      minUnitPrice: _toInt(json['min_unit_price']),
      maxUnitPrice: _toInt(json['max_unit_price']),
      avgUnitPrice: _toInt(json['avg_unit_price']),
      firstDate: json['first_date'] != null
          ? DateTime.tryParse(json['first_date'].toString())
          : null,
      lastDate: json['last_date'] != null
          ? DateTime.tryParse(json['last_date'].toString())
          : null,
    );
  }
}

/// Response endpoint detail riwayat pembelian satu bahan baku.
class ProductPurchaseDetail {
  final int id;
  final String name;
  final String unitName;
  final ProductPurchaseSummary summary;
  final List<ProductPurchaseHistoryItem> history;
  final List<int> availableYears;

  const ProductPurchaseDetail({
    required this.id,
    required this.name,
    required this.unitName,
    required this.summary,
    required this.history,
    this.availableYears = const [],
  });

  factory ProductPurchaseDetail.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? const {};
    return ProductPurchaseDetail(
      id: _toInt(product['id']),
      name: (product['name'] ?? '').toString(),
      unitName: (product['unit']?['unit'] ?? '').toString(),
      summary: ProductPurchaseSummary.fromJson(
        json['summary'] == null
            ? null
            : Map<String, dynamic>.from(json['summary']),
      ),
      history: (json['history'] as List<dynamic>? ?? [])
          .map((e) => ProductPurchaseHistoryItem.fromJson(e))
          .toList(),
      availableYears: (json['available_years'] as List<dynamic>? ?? [])
          .map((e) => _toInt(e))
          .where((y) => y > 0)
          .toList(),
    );
  }
}
