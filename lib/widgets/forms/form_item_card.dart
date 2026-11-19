import 'package:flutter/material.dart';

/// Kartu baris item/produk dinamis untuk form pesanan, transaksi, dan inventaris.
///
/// Memadatkan tata letak produk, kuantitas, harga satuan, dan subtotal ke
/// dalam kartu 3-baris yang rapi: produk+nomor, qty+harga, lalu subtotal
/// rata kanan di baris tersendiri agar nominal sebesar apa pun tetap
/// terbaca penuh.
class FormItemCard extends StatelessWidget {
  final int index;
  final Widget productField;
  final Widget qtyField;
  final Widget priceField;
  final String subtotalText;
  final VoidCallback? onDelete;

  const FormItemCard({
    super.key,
    required this.index,
    required this.productField,
    required this.qtyField,
    required this.priceField,
    required this.subtotalText,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris 1: Nomor Item + Dropdown Produk + Tombol Hapus
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: productField),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: colorScheme.error,
                  tooltip: 'Hapus Item',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Baris 2: Qty + Harga Satuan.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: qtyField,
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: priceField,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Baris 3: Subtotal — baris tersendiri agar label qty/harga tidak
          // terdesak dan nominal ratusan juta / miliar tidak terpotong.
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Subtotal',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    subtotalText,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
