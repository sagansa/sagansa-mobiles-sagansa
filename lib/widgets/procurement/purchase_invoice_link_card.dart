import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../pages/invoice_detail_page.dart';
import '../../services/procurement_service.dart';
import '../../utils/format_utils.dart';
import 'purchase_invoice_picker_sheet.dart';

/// Kartu "Invoice Pembelian Terkait" di detail penjualan direct — kebalikan
/// SalesOrderLinkCard. Hanya dirender untuk admin/super_admin + storage-staff
/// (kondisi di DirectOrderDetailView); set/lepas kaitan lewat endpoint
/// updateInvoice yang sudah ada (hanya bisa untuk invoice draft).
class PurchaseInvoiceLinkCard extends StatefulWidget {
  final int orderId;
  final ProcurementService? service;

  const PurchaseInvoiceLinkCard({
    super.key,
    required this.orderId,
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
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
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
      _reload();
    } catch (e) {
      await _showError(e);
      _reload();
    }
  }

  Future<void> _unlink(InvoiceLinkCandidate invoice) async {
    try {
      await _service.updateInvoice(invoice.id, clearSalesOrderLink: true);
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

    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Invoice Pembelian Terkait',
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<InvoiceLinkCandidate>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  final message =
                      snapshot.error.toString().replaceAll('Exception: ', '');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message, style: TextStyle(color: cs.error)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _reload,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  );
                }
                final invoices = snapshot.data ?? const [];
                if (invoices.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belum ada invoice terkait.',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openPicker,
                          icon: const Icon(Icons.link),
                          label: const Text('Kaitkan Invoice Pembelian'),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    for (final inv in invoices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InvoiceDetailPage(invoiceId: inv.id),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${inv.id} • ${inv.supplierName}',
                                      style: tt.bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${inv.paymentLabel} • '
                                      '${FormatUtils.formatCurrency(inv.totalPrice)}',
                                      style: tt.bodySmall
                                          ?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (inv.isDraft)
                              TextButton(
                                onPressed: () => _unlink(inv),
                                child: const Text('Lepas'),
                              ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openPicker,
                        icon: const Icon(Icons.add_link),
                        label: const Text('Kaitkan Invoice Lain'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
