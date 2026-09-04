import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../utils/format_utils.dart';

/// Kartu "Penjualan Terkait" di detail invoice pembelian — referensi
/// invoice pengiriman ke satu penjualan. [canEdit] = status '1' dan
/// role berhak edit (admin/staff/pembuat).
class SalesOrderLinkCard extends StatelessWidget {
  final InvoicePurchase invoice;
  final bool canEdit;
  final VoidCallback onLink;
  final VoidCallback onUnlink;

  const SalesOrderLinkCard({
    super.key,
    required this.invoice,
    required this.canEdit,
    required this.onLink,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final so = invoice.salesOrder;

    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Penjualan Terkait',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (so == null)
              Text('Belum dikaitkan ke penjualan.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
            else ...[
              _row(tt, 'Penjualan', so.label),
              _row(tt, 'Tipe', so.typeName),
              _row(tt, 'Toko', so.storeName),
              if (so.deliveryDate != null)
                _row(tt, 'Tanggal Kirim', so.deliveryDate!),
              _row(tt, 'Total',
                  FormatUtils.formatCurrency(so.totalPrice)),
            ],
            if (canEdit) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onLink,
                      icon: const Icon(Icons.link, size: 18),
                      label: Text(so == null ? 'Kaitkan ke Penjualan' : 'Ubah'),
                    ),
                  ),
                  if (so != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onUnlink,
                        icon: const Icon(Icons.link_off, size: 18),
                        label: const Text('Lepas'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(TextTheme tt, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.end, style: tt.bodySmall),
            ),
          ],
        ),
      );
}
