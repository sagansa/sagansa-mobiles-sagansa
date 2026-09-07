import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../utils/format_utils.dart';

/// Bottom sheet daftar invoice pembelian (draft + belum terkait) untuk
/// dikaitkan ke penjualan direct. Mode daftar (onSearch(null)) saat dibuka;
/// kolom cari memanggil ulang onSearch dengan keyword (#id / nama supplier).
class PurchaseInvoicePickerSheet extends StatefulWidget {
  final Future<List<InvoiceLinkCandidate>> Function(String? q) onSearch;
  final ValueChanged<InvoiceLinkCandidate> onSelected;

  const PurchaseInvoicePickerSheet({
    super.key,
    required this.onSearch,
    required this.onSelected,
  });

  static Future<InvoiceLinkCandidate?> show(
    BuildContext context, {
    required Future<List<InvoiceLinkCandidate>> Function(String? q) onSearch,
  }) {
    InvoiceLinkCandidate? result;
    return showModalBottomSheet<InvoiceLinkCandidate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PurchaseInvoicePickerSheet(
        onSearch: onSearch,
        onSelected: (c) {
          result = c;
          Navigator.pop(context, c);
        },
      ),
    ).then((_) => result);
  }

  @override
  State<PurchaseInvoicePickerSheet> createState() =>
      _PurchaseInvoicePickerSheetState();
}

class _PurchaseInvoicePickerSheetState extends State<PurchaseInvoicePickerSheet> {
  final _searchController = TextEditingController();
  late Future<List<InvoiceLinkCandidate>> _future;
  String? _query;

  @override
  void initState() {
    super.initState();
    _future = widget.onSearch(null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch(String? q) {
    setState(() {
      _query = (q == null || q.isEmpty) ? null : q;
      _future = widget.onSearch(_query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kaitkan Invoice Pembelian',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Invoice draft yang belum terkait order lain',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari #id atau nama supplier',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _runSearch(null);
                        },
                      ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _runSearch,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<InvoiceLinkCandidate>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final message =
                        snapshot.error.toString().replaceAll('Exception: ', '');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(message,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.error)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => _runSearch(_query),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    );
                  }
                  final results = snapshot.data ?? const [];
                  if (results.isEmpty) {
                    return Center(
                      child: Text(
                          'Tidak ada invoice yang cocok.',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _runSearch(_query),
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) => _candidateTile(results[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _candidateTile(InvoiceLinkCandidate c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => widget.onSelected(c),
        title: Text(
          c.supplierName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('#${c.id}${c.date != null ? ' • ${c.date}' : ''}'),
        trailing: Text(
          FormatUtils.formatCurrency(c.totalPrice),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
