import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/format_utils.dart';
import '../safe_bottom_bar.dart';

/// Bottom sheet daftar invoice pembelian (draft / kandidat) untuk
/// dikaitkan ke penjualan direct. Mode daftar saat dibuka;
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
      backgroundColor: Colors.transparent,
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
      _query = (q == null || q.trim().isEmpty) ? null : q.trim();
      _future = widget.onSearch(_query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.8,
      // Keyboard (kolom cari) + inset sistem bawah (home indicator /
      // gesture bar) — `useSafeArea` sheet hanya melindungi sisi atas.
      margin: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            context.systemBottomInset,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Invoice Pembelian',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invoice sudah dibayar (5 hari terakhir)',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: 'Cari nomor #id atau nama supplier...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _runSearch(null);
                        },
                      ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _runSearch,
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          // List content
          Expanded(
            child: FutureBuilder<List<InvoiceLinkCandidate>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  final message =
                      snapshot.error.toString().replaceAll('Exception: ', '');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 36, color: cs.error),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _runSearch(_query),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final results = snapshot.data ?? const [];
                if (results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _query != null
                                ? 'Tidak ada invoice pembelian yang cocok.'
                                : 'Tidak ada invoice pembelian sudah dibayar dalam 5 hari terakhir.',
                            textAlign: TextAlign.center,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          if (_query != null) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                _runSearch(null);
                              },
                              child: const Text('Tampilkan Semua'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _runSearch(_query),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _candidateTile(results[i], cs, tt),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidateTile(
    InvoiceLinkCandidate c,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => widget.onSelected(c),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45),
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
                Icons.receipt_long_outlined,
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${c.id}',
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
                          c.supplierName,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        c.paymentLabel,
                        style: tt.labelSmall?.copyWith(
                          color: c.isDraft
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      if (c.date != null && c.date!.isNotEmpty) ...[
                        Text(
                          ' • ${c.date}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FormatUtils.formatCurrency(c.totalPrice),
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Pilih',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
