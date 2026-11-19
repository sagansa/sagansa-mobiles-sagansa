import 'package:flutter/material.dart';

/// Baris ringkas untuk menampilkan item produk pada halaman detail order / transaksi.
class DetailProductTile extends StatelessWidget {
  final String productName;
  final String? productUnit;
  final int quantity;
  final int? unitPrice;
  final int? subtotalPrice;
  final String? formattedUnitPrice;
  final String? formattedSubtotalPrice;
  final bool showPrice;

  const DetailProductTile({
    super.key,
    required this.productName,
    this.productUnit,
    required this.quantity,
    this.unitPrice,
    this.subtotalPrice,
    this.formattedUnitPrice,
    this.formattedSubtotalPrice,
    this.showPrice = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final unitLabel = productUnit != null && productUnit!.isNotEmpty
        ? ' $productUnit'
        : ' pcs';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Chip kuantitas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '$quantity$unitLabel',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Nama & detail produk
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  productName,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (showPrice && (formattedUnitPrice != null || unitPrice != null)) ...[
                  const SizedBox(height: 1),
                  Text(
                    formattedUnitPrice ?? 'Rp $unitPrice',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Subtotal
          if (showPrice && (formattedSubtotalPrice != null || subtotalPrice != null))
            Text(
              formattedSubtotalPrice ?? 'Rp $subtotalPrice',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}
