import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../utils/format_utils.dart';
import '../detail/detail_section_card.dart';
import '../detail_row.dart';

/// Kartu "Penjualan Terkait" di detail invoice pembelian — referensi
/// invoice pengiriman ke satu penjualan. [canEdit] = role berhak
/// (storage-staff & admin).
///
/// Memakai [DetailSectionCard] agar geometri (radius, padding, lebar)
/// konsisten dengan kartu-kartu section lain di halaman detail.
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

    return DetailSectionCard(
      icon: Icons.link,
      title: 'Penjualan Terkait',
      children: [
        if (so == null)
          Text('Belum dikaitkan ke penjualan.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
        else ...[
          DetailRow(label: 'Penjualan', value: so.label, valueBold: true),
          DetailRow(label: 'Tipe', value: so.typeName),
          DetailRow(label: 'Toko', value: so.storeName),
          if (so.deliveryDate != null)
            DetailRow(label: 'Tanggal Kirim', value: so.deliveryDate!),
          DetailRow(
              label: 'Total', value: FormatUtils.formatCurrency(so.totalPrice)),
        ],
        if (canEdit) ...[
          const SizedBox(height: 4),
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
    );
  }
}
