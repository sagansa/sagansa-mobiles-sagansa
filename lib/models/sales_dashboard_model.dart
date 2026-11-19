enum SalesPeriode {
  today,
  yesterday,
  month,
  lastMonth,
  year,
  lastYear;

  String get apiValue => switch (this) {
        SalesPeriode.today => 'today',
        SalesPeriode.yesterday => 'yesterday',
        SalesPeriode.month => 'month',
        SalesPeriode.lastMonth => 'last_month',
        SalesPeriode.year => 'year',
        SalesPeriode.lastYear => 'last_year',
      };

  String get label => switch (this) {
        SalesPeriode.today => 'Hari ini',
        SalesPeriode.yesterday => 'Kemarin',
        SalesPeriode.month => 'Bulan ini',
        SalesPeriode.lastMonth => 'Bulan lalu',
        SalesPeriode.year => 'Tahun ini',
        SalesPeriode.lastYear => 'Tahun lalu',
      };

  String get expectedInterval => switch (this) {
        SalesPeriode.today => 'hour',
        SalesPeriode.yesterday => 'hour',
        SalesPeriode.month => 'day',
        SalesPeriode.lastMonth => 'day',
        SalesPeriode.year => 'month',
        SalesPeriode.lastYear => 'month',
      };
}

enum SalesView { summary, trend, products, channels, categories }

enum ProductSort { qty, revenue }

class SalesSummary {
  final String periodeLabel;
  final int omzet;
  final int orderCount;
  final int totalQty;
  // Pembanding periode natural (today↔kemarin, month↔bulan lalu paralel, dst).
  final int omzetPrev;
  final int orderCountPrev;
  final int totalQtyPrev;
  final String prevLabel;

  const SalesSummary({
    required this.periodeLabel,
    required this.omzet,
    required this.orderCount,
    required this.totalQty,
    required this.omzetPrev,
    required this.orderCountPrev,
    required this.totalQtyPrev,
    required this.prevLabel,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> j) => SalesSummary(
        periodeLabel: j['periode_label'] as String? ?? '',
        omzet: (j['omzet'] as num? ?? 0).toInt(),
        orderCount: (j['order_count'] as num? ?? 0).toInt(),
        totalQty: (j['total_qty'] as num? ?? 0).toInt(),
        omzetPrev: (j['omzet_prev'] as num? ?? 0).toInt(),
        orderCountPrev: (j['order_count_prev'] as num? ?? 0).toInt(),
        totalQtyPrev: (j['total_qty_prev'] as num? ?? 0).toInt(),
        prevLabel: j['prev_label'] as String? ?? '',
      );
}

class SalesTrendPoint {
  final String label;
  final int value;
  final int? valuePrev;

  const SalesTrendPoint({required this.label, required this.value, this.valuePrev});

  factory SalesTrendPoint.fromJson(Map<String, dynamic> j) => SalesTrendPoint(
        label: j['label'] as String? ?? '',
        value: (j['value'] as num? ?? 0).toInt(),
        valuePrev: (j['value_prev'] as num?)?.toInt(),
      );
}

class SalesProductItem {
  final int productId;
  final String? productName;
  final String? categoryName;
  final String? unit;
  final int qty;
  final int revenue;
  final int qtyPrev;
  final int revenuePrev;

  const SalesProductItem({
    required this.productId,
    required this.productName,
    this.categoryName,
    required this.unit,
    required this.qty,
    required this.revenue,
    this.qtyPrev = 0,
    this.revenuePrev = 0,
  });

  factory SalesProductItem.fromJson(Map<String, dynamic> j) => SalesProductItem(
        productId: (j['product_id'] as num).toInt(),
        productName: j['product_name'] as String?,
        categoryName: j['category_name'] as String?,
        unit: j['unit'] as String?,
        qty: (j['qty'] as num? ?? 0).toInt(),
        revenue: (j['revenue'] as num? ?? 0).toInt(),
        qtyPrev: (j['qty_prev'] as num? ?? 0).toInt(),
        revenuePrev: (j['revenue_prev'] as num? ?? 0).toInt(),
      );
}

class SalesCategorySummaryItem {
  final String categoryName;
  final int qty;
  final int revenue;
  final double percentage;

  const SalesCategorySummaryItem({
    required this.categoryName,
    required this.qty,
    required this.revenue,
    required this.percentage,
  });

  factory SalesCategorySummaryItem.fromJson(Map<String, dynamic> j) =>
      SalesCategorySummaryItem(
        categoryName: j['category_name'] as String? ?? 'Umum',
        qty: (j['qty'] as num? ?? 0).toInt(),
        revenue: (j['revenue'] as num? ?? 0).toInt(),
        percentage: (j['percentage'] as num? ?? 0).toDouble(),
      );
}

class SalesProductMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final String prevLabel;

  const SalesProductMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.prevLabel = '',
  });

  factory SalesProductMeta.fromJson(Map<String, dynamic> j) => SalesProductMeta(
        currentPage: (j['current_page'] as num? ?? 1).toInt(),
        lastPage: (j['last_page'] as num? ?? 1).toInt(),
        perPage: (j['per_page'] as num? ?? 50).toInt(),
        total: (j['total'] as num? ?? 0).toInt(),
        prevLabel: j['prev_label'] as String? ?? '',
      );

  bool get hasMore => currentPage < lastPage;
}

class SalesChannelItem {
  final String channel;
  final String channelLabel;
  final int omzet;
  final int orderCount;
  final int qty;
  final double percentage;
  final int omzetPrev;
  final int orderCountPrev;
  final int qtyPrev;

  const SalesChannelItem({
    required this.channel,
    required this.channelLabel,
    required this.omzet,
    required this.orderCount,
    required this.qty,
    required this.percentage,
    this.omzetPrev = 0,
    this.orderCountPrev = 0,
    this.qtyPrev = 0,
  });

  factory SalesChannelItem.fromJson(Map<String, dynamic> j) => SalesChannelItem(
        // `channel` bisa int (DB tinyint di production) atau string (test
        // factory). Normalisasi ke string agar switch _colorFor stabil.
        channel: (j['channel'] ?? '').toString(),
        channelLabel: j['channel_label'] as String? ?? '',
        omzet: (j['omzet'] as num? ?? 0).toInt(),
        orderCount: (j['order_count'] as num? ?? 0).toInt(),
        qty: (j['qty'] as num? ?? 0).toInt(),
        percentage: (j['percentage'] as num? ?? 0).toDouble(),
        omzetPrev: (j['omzet_prev'] as num? ?? 0).toInt(),
        orderCountPrev: (j['order_count_prev'] as num? ?? 0).toInt(),
        qtyPrev: (j['qty_prev'] as num? ?? 0).toInt(),
      );
}

class SalesChannelsResult {
  final List<SalesChannelItem> items;
  final int totalOmzet;
  final int totalOmzetPrev;
  final int totalQty;
  final int totalQtyPrev;
  final int totalOrders;
  final int totalOrdersPrev;
  final String prevLabel;
  final int? compareYear;

  const SalesChannelsResult({
    required this.items,
    required this.totalOmzet,
    this.totalOmzetPrev = 0,
    this.totalQty = 0,
    this.totalQtyPrev = 0,
    this.totalOrders = 0,
    this.totalOrdersPrev = 0,
    this.prevLabel = '',
    this.compareYear,
  });

  factory SalesChannelsResult.fromJson(Map<String, dynamic> j) => SalesChannelsResult(
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((e) => SalesChannelItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalOmzet: (j['total_omzet'] as num? ?? 0).toInt(),
        totalOmzetPrev: (j['total_omzet_prev'] as num? ?? 0).toInt(),
        totalQty: (j['total_qty'] as num? ?? 0).toInt(),
        totalQtyPrev: (j['total_qty_prev'] as num? ?? 0).toInt(),
        totalOrders: (j['total_orders'] as num? ?? 0).toInt(),
        totalOrdersPrev: (j['total_orders_prev'] as num? ?? 0).toInt(),
        prevLabel: j['prev_label'] as String? ?? '',
        compareYear: j['compare_year'] as int?,
      );
}

class SalesCategoryTopProduct {
  final String name;
  final int qty;
  final int omzet;

  const SalesCategoryTopProduct({
    required this.name,
    required this.qty,
    required this.omzet,
  });

  String get productName => name;
  int get revenue => omzet;

  factory SalesCategoryTopProduct.fromJson(Map<String, dynamic> j) =>
      SalesCategoryTopProduct(
        name: j['name'] as String? ?? '',
        qty: (j['qty'] as num? ?? 0).toInt(),
        omzet: (j['omzet'] as num? ?? 0).toInt(),
      );
}

class SalesCategoryItem {
  final int categoryId;
  final String categoryName;
  final int omzet;
  final int qty;
  final int orderCount;
  final double percentage;
  final int omzetPrev;
  final int qtyPrev;
  final List<SalesCategoryTopProduct> topProducts;

  const SalesCategoryItem({
    required this.categoryId,
    required this.categoryName,
    required this.omzet,
    required this.qty,
    required this.orderCount,
    required this.percentage,
    this.omzetPrev = 0,
    this.qtyPrev = 0,
    this.topProducts = const [],
  });

  int get revenue => omzet;
  int get revenuePrev => omzetPrev;
  int get productCount => topProducts.length;

  factory SalesCategoryItem.fromJson(Map<String, dynamic> j) => SalesCategoryItem(
        categoryId: (j['category_id'] as num? ?? 0).toInt(),
        categoryName: j['category_name'] as String? ?? 'Umum',
        omzet: (j['omzet'] as num? ?? 0).toInt(),
        qty: (j['qty'] as num? ?? 0).toInt(),
        orderCount: (j['order_count'] as num? ?? 0).toInt(),
        percentage: (j['percentage'] as num? ?? 0).toDouble(),
        omzetPrev: (j['omzet_prev'] as num? ?? 0).toInt(),
        qtyPrev: (j['qty_prev'] as num? ?? 0).toInt(),
        topProducts: ((j['top_products'] as List<dynamic>?) ?? const [])
            .map((e) => SalesCategoryTopProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SalesCategoriesResult {
  final List<SalesCategoryItem> items;
  final int totalOmzet;
  final int totalQty;
  final String prevLabel;

  const SalesCategoriesResult({
    required this.items,
    required this.totalOmzet,
    required this.totalQty,
    this.prevLabel = '',
  });

  int get totalCategories => items.length;
  int get totalOmzetPrev => items.fold(0, (sum, it) => sum + it.omzetPrev);
  int get totalQtyPrev => items.fold(0, (sum, it) => sum + it.qtyPrev);

  factory SalesCategoriesResult.fromJson(Map<String, dynamic> j) => SalesCategoriesResult(
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((e) => SalesCategoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalOmzet: (j['total_omzet'] as num? ?? 0).toInt(),
        totalQty: (j['total_qty'] as num? ?? 0).toInt(),
        prevLabel: j['prev_label'] as String? ?? '',
      );
}

