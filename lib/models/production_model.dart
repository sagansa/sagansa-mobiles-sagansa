/// Model produksi & resep untuk mobile apps.
///
/// Struktur mengikuti API endpoint:
///   GET    /recipes, /recipes/{id}, /recipes/by-product/{productId}
///   GET    /productions, /productions/{id}
///   POST   /productions (+ prefill dari recipe_id)
///   PUT    /productions/{id}, /productions/{id}/items/{itemId}
///   POST   /productions/{id}/items, /productions/{id}/apply, /productions/{id}/revert
///   DELETE /productions/{id}/items/{itemId}
library;

/// Produk ringkas — hanya field yang ditampilkan di UI mobile.
class ProductionProduct {
  final int id;
  final String name;
  final String? sku;

  const ProductionProduct({
    required this.id,
    required this.name,
    this.sku,
  });

  factory ProductionProduct.fromJson(Map<String, dynamic> j) => ProductionProduct(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        sku: j['sku'] as String?,
      );
}

class ProductionUnit {
  final int id;
  final String name;

  const ProductionUnit({required this.id, required this.name});

  factory ProductionUnit.fromJson(Map<String, dynamic> j) => ProductionUnit(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
      );
}

/// Baris ingredient dalam resep (master).
class RecipeIngredient {
  final int id;
  final ProductionProduct product;
  final double quantity;
  final ProductionUnit? unit;
  final bool isOptional;

  const RecipeIngredient({
    required this.id,
    required this.product,
    required this.quantity,
    this.unit,
    this.isOptional = false,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        id: (j['id'] as num).toInt(),
        product: ProductionProduct.fromJson(j['product'] as Map<String, dynamic>),
        quantity: (j['quantity'] as num? ?? 0).toDouble(),
        unit: j['unit'] == null
            ? null
            : ProductionUnit.fromJson(j['unit'] as Map<String, dynamic>),
        isOptional: (j['is_optional'] as num? ?? 0) != 0,
      );
}

/// Resep master (default ingredients untuk membuat sebuah produk output).
class Recipe {
  final int id;
  final ProductionProduct product;
  final double outputQty;
  final ProductionUnit? outputUnit;
  final String? name;
  final bool isActive;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    required this.id,
    required this.product,
    required this.outputQty,
    this.outputUnit,
    this.name,
    this.isActive = true,
    this.ingredients = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: (j['id'] as num).toInt(),
        product: ProductionProduct.fromJson(j['product'] as Map<String, dynamic>),
        outputQty: (j['output_qty'] as num? ?? 1).toDouble(),
        outputUnit: j['output_unit'] == null
            ? null
            : ProductionUnit.fromJson(j['output_unit'] as Map<String, dynamic>),
        name: j['name'] as String?,
        isActive: (j['is_active'] as num? ?? 1) != 0,
        ingredients: ((j['ingredients'] as List?) ?? const [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Sumber item produksi.
enum ProductionItemSource { recipeDefault, invoice, manual }

ProductionItemSource _parseSource(String? s) => switch (s) {
      'invoice' => ProductionItemSource.invoice,
      'recipe_default' => ProductionItemSource.recipeDefault,
      _ => ProductionItemSource.manual,
    };

String sourceValue(ProductionItemSource s) => switch (s) {
      ProductionItemSource.invoice => 'invoice',
      ProductionItemSource.recipeDefault => 'recipe_default',
      ProductionItemSource.manual => 'manual',
    };

/// Arah item: in (bahan baku dikonsumsi) atau out (hasil produksi).
enum ProductionItemDirection { input, output }

ProductionItemDirection _parseDirection(String? s) => switch (s) {
      'out' => ProductionItemDirection.output,
      _ => ProductionItemDirection.input,
    };

String directionValue(ProductionItemDirection d) =>
    d == ProductionItemDirection.output ? 'out' : 'in';

/// Item produksi (snapshot bahan baku / output hasil).
class ProductionItem {
  final int? id;
  final ProductionProduct product;
  final ProductionItemDirection direction;
  final ProductionItemSource source;
  final double quantity;
  final ProductionUnit? unit;
  final int? detailInvoiceId;
  final int? recipeIngredientId;
  final String? notes;

  const ProductionItem({
    this.id,
    required this.product,
    required this.direction,
    this.source = ProductionItemSource.manual,
    required this.quantity,
    this.unit,
    this.detailInvoiceId,
    this.recipeIngredientId,
    this.notes,
  });

  factory ProductionItem.fromJson(Map<String, dynamic> j) => ProductionItem(
        id: (j['id'] as num?)?.toInt(),
        product: ProductionProduct.fromJson(j['product'] as Map<String, dynamic>),
        direction: _parseDirection(j['direction'] as String?),
        source: _parseSource(j['source'] as String?),
        quantity: (j['quantity'] as num? ?? 0).toDouble(),
        unit: j['unit'] == null
            ? null
            : ProductionUnit.fromJson(j['unit'] as Map<String, dynamic>),
        detailInvoiceId: (j['detail_invoice_id'] as num?)?.toInt(),
        recipeIngredientId: (j['recipe_ingredient_id'] as num?)?.toInt(),
        notes: j['notes'] as String?,
      );

  /// JSON untuk POST/PUT ke API. Produk & unit hanya kirim id.
  Map<String, dynamic> toJson() => {
        'product_id': product.id,
        'direction': directionValue(direction),
        'source': sourceValue(source),
        'quantity': quantity,
        if (unit != null) 'unit_id': unit!.id,
        if (detailInvoiceId != null) 'detail_invoice_id': detailInvoiceId,
        if (recipeIngredientId != null) 'recipe_ingredient_id': recipeIngredientId,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  ProductionItem copyWith({
    double? quantity,
    ProductionUnit? unit,
    String? notes,
    bool clearNotes = false,
  }) =>
      ProductionItem(
        id: id,
        product: product,
        direction: direction,
        source: source,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        detailInvoiceId: detailInvoiceId,
        recipeIngredientId: recipeIngredientId,
        notes: clearNotes ? null : (notes ?? this.notes),
      );
}

/// Baris detail invoice pembelian yang masih tersedia (status '1') untuk
/// dijadikan bahan baku produksi — definisi admin: produksi wajib dibuat
/// berdasarkan invoice.
class ProductionDetailInvoice {
  final int id;
  final int? productId;
  final String productName;
  final int? unitId;
  final String unitName;
  final double quantityProduct;
  final int? invoicePurchaseId;
  final String? invoiceDate;

  const ProductionDetailInvoice({
    required this.id,
    this.productId,
    required this.productName,
    this.unitId,
    this.unitName = '',
    required this.quantityProduct,
    this.invoicePurchaseId,
    this.invoiceDate,
  });

  factory ProductionDetailInvoice.fromJson(Map<String, dynamic> j) =>
      ProductionDetailInvoice(
        id: (j['id'] as num).toInt(),
        productId: (j['product_id'] as num?)?.toInt(),
        productName: j['product_name'] as String? ?? '-',
        unitId: (j['unit_id'] as num?)?.toInt(),
        unitName: j['unit_name'] as String? ?? '',
        quantityProduct: (j['quantity_product'] as num? ?? 0).toDouble(),
        invoicePurchaseId: (j['invoice_purchase_id'] as num?)?.toInt(),
        invoiceDate: j['invoice_date'] as String?,
      );

  /// Label ringkas ala admin: produk + qty + tanggal invoice.
  String get label {
    final qty = quantityProduct == quantityProduct.roundToDouble()
        ? quantityProduct.toStringAsFixed(0)
        : quantityProduct.toStringAsFixed(2);
    return '$productName — $qty ${unitName.isEmpty ? '' : unitName}'.trim();
  }
}

/// Store ringkas — nickname/name untuk display.
class ProductionStore {
  final int id;
  final String nickname;
  final String? name;

  const ProductionStore({
    required this.id,
    required this.nickname,
    this.name,
  });

  factory ProductionStore.fromJson(Map<String, dynamic> j) => ProductionStore(
        id: (j['id'] as num).toInt(),
        nickname: j['nickname'] as String? ?? '',
        name: j['name'] as String?,
      );
}

/// Production record utuh (header + items).
class Production {
  final int id;
  final ProductionStore? store;
  final Recipe? recipe; // null bila produksi tanpa resep
  final DateTime date;
  final String status; // '1'..'4' (string, konsisten dgn backend)
  final String? notes;
  final DateTime? appliedAt;
  final DateTime? createdAt;
  final List<ProductionItem> items;

  const Production({
    required this.id,
    this.store,
    this.recipe,
    required this.date,
    required this.status,
    this.notes,
    this.appliedAt,
    this.createdAt,
    this.items = const [],
  });

  factory Production.fromJson(Map<String, dynamic> j) => Production(
        id: (j['id'] as num).toInt(),
        store: j['store'] == null
            ? null
            : ProductionStore.fromJson(j['store'] as Map<String, dynamic>),
        recipe: j['recipe'] == null
            ? null
            : Recipe.fromJson(j['recipe'] as Map<String, dynamic>),
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        status: (j['status'] ?? '1').toString(),
        notes: j['notes'] as String?,
        appliedAt: j['applied_at'] == null
            ? null
            : DateTime.tryParse(j['applied_at'] as String),
        createdAt: j['created_at'] == null
            ? null
            : DateTime.tryParse(j['created_at'] as String),
        items: ((j['items'] as List?) ?? const [])
            .map((e) => ProductionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isApplied => appliedAt != null;

  /// Label status (1=belum diperiksa, 2=valid, 3=perbaiki, 4=periksa ulang).
  String get statusLabel => switch (status) {
        '2' => 'Valid',
        '3' => 'Perbaiki',
        '4' => 'Periksa ulang',
        _ => 'Belum diperiksa',
      };
}
