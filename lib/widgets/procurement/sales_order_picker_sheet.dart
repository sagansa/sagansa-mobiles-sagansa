import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../utils/format_utils.dart';
import '../safe_bottom_bar.dart';

/// Bottom sheet daftar penjualan untuk dikaitkan ke invoice.
///
/// [onLoad] memuat daftar kandidat — order toko online 5 hari terakhir,
/// terbaru dulu. Daftar dimuat otomatis saat sheet dibuka (tanpa input
/// nomor resi: order toko online tidak punya resi) dan bisa di-refresh
/// lewat pull-down.
class SalesOrderPickerSheet extends StatefulWidget {
  final Future<List<SalesOrderCandidate>> Function() onLoad;
  final ValueChanged<SalesOrderCandidate> onSelected;

  const SalesOrderPickerSheet({
    super.key,
    required this.onLoad,
    required this.onSelected,
  });

  static Future<SalesOrderCandidate?> show(
    BuildContext context, {
    required Future<List<SalesOrderCandidate>> Function() onLoad,
  }) {
    SalesOrderCandidate? result;
    return showModalBottomSheet<SalesOrderCandidate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SalesOrderPickerSheet(
        onLoad: onLoad,
        onSelected: (c) {
          result = c;
          Navigator.pop(context, c);
        },
      ),
    ).then((_) => result);
  }

  @override
  State<SalesOrderPickerSheet> createState() => _SalesOrderPickerSheetState();
}

class _SalesOrderPickerSheetState extends State<SalesOrderPickerSheet> {
  late Future<List<SalesOrderCandidate>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.onLoad();
  }

  void _reload() {
    // setState tidak boleh mengembalikan Future dari callback-nya —
    // assignment Future onLoad harus di dalam block, bukan expression.
    setState(() {
      _future = widget.onLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        // Inset sistem bawah (home indicator / gesture bar) — tanpa ini
        // kandidat terakhir tertutup; `useSafeArea` hanya sisi atas.
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + context.systemBottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kaitkan ke Penjualan',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Order toko online 5 hari terakhir',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<SalesOrderCandidate>>(
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
                            onPressed: _reload,
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    );
                  }
                  final results = snapshot.data ?? const [];
                  if (results.isEmpty) {
                    return Center(
                      child: Text('Tidak ada order 5 hari terakhir.',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
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

  Widget _candidateTile(SalesOrderCandidate c) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => widget.onSelected(c),
        // Identitas pembeli jadi info utama — staf mencocokkan order dari
        // nama/alamat pembeli, bukan nomor resi (order toko online tidak
        // punya resi).
        title: Text(c.buyerName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.buyerPhone.isNotEmpty) Text(c.buyerPhone),
            if (c.buyerAddress.isNotEmpty)
              Text(c.buyerAddress,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${c.label} • ${c.deliveryDate ?? '-'}',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        isThreeLine: c.buyerAddress.isNotEmpty,
        trailing: Text(FormatUtils.formatCurrency(c.totalPrice),
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
