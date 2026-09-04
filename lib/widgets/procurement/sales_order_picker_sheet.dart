import 'package:flutter/material.dart';
import '../../models/procurement_model.dart';
import '../../utils/format_utils.dart';

/// Bottom sheet pencarian penjualan untuk dikaitkan ke invoice.
/// [onSearch] dipanggil dengan query; hasil ditampilkan sebagai kartu.
class SalesOrderPickerSheet extends StatefulWidget {
  final Future<List<SalesOrderCandidate>> Function(String query) onSearch;
  final ValueChanged<SalesOrderCandidate> onSelected;

  const SalesOrderPickerSheet({
    super.key,
    required this.onSearch,
    required this.onSelected,
  });

  static Future<SalesOrderCandidate?> show(
    BuildContext context, {
    required Future<List<SalesOrderCandidate>> Function(String) onSearch,
  }) {
    SalesOrderCandidate? result;
    return showModalBottomSheet<SalesOrderCandidate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SalesOrderPickerSheet(
        onSearch: onSearch,
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
  final _controller = TextEditingController();
  List<SalesOrderCandidate>? _results;
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isSearching = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await widget.onSearch(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kaitkan ke Penjualan',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'No. resi / no. order',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isSearching ? null : _search,
                child: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cari'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: TextStyle(color: cs.error)),
          if (_results != null && _results!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Penjualan tidak ditemukan.',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
            )
          else if (_results != null)
            Expanded(
              child: ListView.builder(
                itemCount: _results!.length,
                itemBuilder: (context, i) => _candidateTile(_results![i]),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _candidateTile(SalesOrderCandidate c) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => widget.onSelected(c),
        title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${c.typeName} • ${c.storeName}'
            '${c.deliveryDate != null ? ' • ${c.deliveryDate}' : ''}'),
        trailing: Text(FormatUtils.formatCurrency(c.totalPrice),
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
