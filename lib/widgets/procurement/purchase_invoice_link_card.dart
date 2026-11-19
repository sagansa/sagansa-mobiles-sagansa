import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../pages/invoice_detail_page.dart';
import '../../services/procurement_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format_utils.dart';
import '../app_snackbar.dart';
import '../detail/detail_section_card.dart';
import 'purchase_invoice_picker_sheet.dart';

/// Kartu "Invoice Pembelian Terkait" di detail penjualan direct.
/// Menampilkan daftar invoice pembelian yang terhubung ke sales order ini
/// dan menyediakan tombol untuk memilih & mengaitkan invoice dari daftar pembelian.
class PurchaseInvoiceLinkCard extends StatefulWidget {
  final int orderId;
  final bool canEdit;
  final ProcurementService? service;

  const PurchaseInvoiceLinkCard({
    super.key,
    required this.orderId,
    this.canEdit = true,
    this.service,
  });

  @override
  State<PurchaseInvoiceLinkCard> createState() =>
      _PurchaseInvoiceLinkCardState();
}

class _PurchaseInvoiceLinkCardState extends State<PurchaseInvoiceLinkCard> {
  late final ProcurementService _service;
  late Future<List<InvoiceLinkCandidate>> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProcurementService();
    _future = _service.getPurchaseInvoices(widget.orderId);
  }

  void _reload() {
    setState(() {
      _future = _service.getPurchaseInvoices(widget.orderId);
    });
  }

  Future<void> _showError(Object e) async {
    if (!mounted) return;
    final message = e.toString().replaceAll('Exception: ', '');
    showAppSnackBar(
      context,
      message,
      background: Theme.of(context).colorScheme.error,
    );
  }

  Future<void> _openPicker() async {
    final picked = await PurchaseInvoicePickerSheet.show(
      context,
      onSearch: (q) => _service.getInvoiceLinkCandidates(q: q),
    );
    if (picked == null) return;
    try {
      await _service.updateInvoice(picked.id, salesOrderId: widget.orderId);
      if (mounted) {
        showAppSnackBar(
          context,
          'Invoice #${picked.id} berhasil dihubungkan ke penjualan.',
          background: Colors.green.shade600,
        );
      }
      _reload();
    } catch (e) {
      await _showError(e);
      _reload();
    }
  }

  Future<void> _unlink(InvoiceLinkCandidate invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lepas Kaitan Invoice'),
        content: Text(
          'Apakah Anda yakin ingin melepas kaitan invoice #${invoice.id} (${invoice.supplierName}) dari order penjualan ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Lepas'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.updateInvoice(invoice.id, clearSalesOrderLink: true);
      if (mounted) {
        showAppSnackBar(
          context,
          'Kaitan invoice #${invoice.id} berhasil dilepas.',
          background: Colors.green.shade600,
        );
      }
      _reload();
    } catch (e) {
      await _showError(e);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FutureBuilder<List<InvoiceLinkCandidate>>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState != ConnectionState.done;
        final hasError = snapshot.hasError;
        final invoices = snapshot.data ?? const [];

        return DetailSectionCard(
          title: 'Invoice Pembelian Terkait',
          icon: Icons.receipt_long_outlined,
          trailing: widget.canEdit
              ? TextButton.icon(
                  onPressed: _openPicker,
                  icon: const Icon(Icons.add_link, size: 16),
                  label: const Text(
                    'Kaitkan',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                )
              : null,
          children: [
            if (isLoading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ] else if (hasError) ...[
              _buildErrorState(cs, tt, snapshot.error!),
            ] else if (invoices.isEmpty) ...[
              _buildEmptyState(cs, tt),
            ] else ...[
              _buildInvoicesList(cs, tt, invoices),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Belum ada invoice pembelian yang dihubungkan ke penjualan ini.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (widget.canEdit) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _openPicker,
              icon: const Icon(Icons.link, size: 18),
              label: const Text(
                'Hubungkan Invoice Pembelian',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState(ColorScheme cs, TextTheme tt, Object error) {
    final raw = error.toString().replaceAll('Exception: ', '');
    final routeMissing = raw.toLowerCase().contains('could not be found');
    final message = routeMissing
        ? 'Fitur sinkronisasi invoice pembelian terkait belum tersedia di server.'
        : raw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            color: routeMissing ? cs.onSurfaceVariant : cs.error,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _reload,
              child: const Text('Coba lagi', style: TextStyle(fontSize: 12)),
            ),
            if (widget.canEdit) ...[
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: _openPicker,
                icon: const Icon(Icons.link, size: 14),
                label: const Text('Pilih Invoice',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInvoicesList(
    ColorScheme cs,
    TextTheme tt,
    List<InvoiceLinkCandidate> invoices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < invoices.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildInvoiceTile(cs, tt, invoices[i]),
        ],
        if (widget.canEdit) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _openPicker,
              icon: const Icon(Icons.add_link, size: 16),
              label: const Text('Hubungkan Invoice Lain'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInvoiceTile(
    ColorScheme cs,
    TextTheme tt,
    InvoiceLinkCandidate inv,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_outlined,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailPage(invoiceId: inv.id),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${inv.id}',
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          inv.supplierName,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        inv.paymentLabel,
                        style: tt.labelSmall?.copyWith(
                          color: inv.isDraft
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      if (inv.date != null && inv.date!.isNotEmpty)
                        Text(
                          ' • ${inv.date}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    FormatUtils.formatCurrency(inv.totalPrice),
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.canEdit) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.link_off_rounded,
                color: cs.error,
                size: 18,
              ),
              tooltip: 'Lepas Kaitan',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _unlink(inv),
            ),
          ],
        ],
      ),
    );
  }
}
