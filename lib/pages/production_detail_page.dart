import 'package:flutter/material.dart';
import '../models/production_model.dart';
import '../services/production_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';

/// Detail produksi: tampilkan header, list item (input/output), dan tombol
/// apply/revert stok. Item tidak bisa diedit bila production sudah applied
/// (konsisten dengan backend).
class ProductionDetailPage extends StatefulWidget {
  final int id;
  const ProductionDetailPage({super.key, required this.id});

  @override
  State<ProductionDetailPage> createState() => _ProductionDetailPageState();
}

class _ProductionDetailPageState extends State<ProductionDetailPage> {
  final ProductionService _service = ProductionService();
  Production? _production;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _service.show(widget.id);
      if (!mounted) return;
      setState(() {
        _production = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggleApply() async {
    final p = _production;
    if (p == null) return;
    final isApplied = p.isApplied;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApplied ? 'Batalkan Stok?' : 'Terapkan Stok?'),
        content: Text(isApplied
            ? 'Stok ingredient akan dikembalikan, stok output akan dikurangi.'
            : 'Stok ingredient akan dikurangi, stok output akan ditambah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      if (isApplied) {
        await _service.revert(p.id);
      } else {
        await _service.apply(p.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isApplied ? 'Stok dibatalkan.' : 'Stok diterapkan.')),
      );
      await _load();
      // Beritahu parent (list) supaya refresh juga.
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(title: const Text('Detail Produksi')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            AppSpacing.gapVerticalMD,
            FilledButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    final p = _production;
    if (p == null) return const Center(child: Text('Produksi tidak ditemukan.'));

    final inputs =
        p.items.where((i) => i.direction == ProductionItemDirection.input).toList();
    final outputs =
        p.items.where((i) => i.direction == ProductionItemDirection.output).toList();

    return ListView(
      padding: AppSpacing.paddingMD.copyWith(
        top: AppBarInsets.top(context),
      ),
      children: [
        _headerCard(p),
        AppSpacing.gapVerticalMD,
        _sectionTitle('Hasil Produksi', Icons.arrow_circle_up_outlined),
        ...outputs.map((i) => _itemTile(i, isOutput: true)),
        AppSpacing.gapVerticalMD,
        _sectionTitle('Bahan Baku', Icons.arrow_circle_down_outlined),
        ...inputs.map((i) => _itemTile(i, isOutput: false)),
        AppSpacing.gapVerticalLG,
        if (p.notes != null && p.notes!.isNotEmpty) ...[
          _sectionTitle('Catatan', Icons.note_outlined),
          Container(
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: AppSpacing.borderRadiusSM,
            ),
            child: Text(p.notes!),
          ),
          AppSpacing.gapVerticalLG,
        ],
        _applyButton(p),
        AppSpacing.gapVerticalMD,
      ],
    );
  }

  Widget _headerCard(Production p) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.recipe?.product.name ?? 'Produksi Manual',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (p.isApplied)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: AppSpacing.borderRadiusSM,
                    ),
                    child: Text(
                      'Stok diterapkan',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            AppSpacing.gapVerticalXS,
            Text(
              '${p.store?.nickname ?? '-'} · ${FormatUtils.formatDate(p.date)}',
              style: theme.textTheme.bodySmall,
            ),
            AppSpacing.gapVerticalXS,
            Wrap(
              spacing: 8,
              children: [
                _chip('Status: ${p.statusLabel}', cs.surfaceContainerHighest),
                if (p.recipe != null)
                  _chip('Resep: ${p.recipe!.product.name}', cs.surfaceContainerHighest),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _itemTile(ProductionItem item, {required bool isOutput}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          isOutput ? Icons.add_circle : Icons.remove_circle,
          color: isOutput ? AppColors.success : AppColors.warning,
          size: 20,
        ),
        title: Text(item.product.name),
        subtitle: Text(
          '${_fmtQty(item.quantity)}'
          '${item.unit != null ? ' ${item.unit!.name}' : ''}'
          ' · ${_sourceLabel(item.source)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: item.notes == null
            ? null
            : Icon(Icons.note_alt_outlined,
                size: 18, color: theme.colorScheme.outline),
      ),
    );
  }

  Widget _applyButton(Production p) {
    if (p.items.isEmpty) {
      return const Text(
        'Belum ada item. Hubungi admin untuk menambahkan item via panel web.',
        textAlign: TextAlign.center,
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _actionLoading ? null : _toggleApply,
        icon: _actionLoading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(p.isApplied ? Icons.undo : Icons.check_circle),
        label: Text(
          p.isApplied ? 'Batalkan Stok' : 'Terapkan Stok',
        ),
        style: AppButtonStyle.filled(
          backgroundColor: p.isApplied ? AppColors.warning : AppColors.success,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.borderRadiusSM,
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  String _fmtQty(double q) =>
      q.toStringAsFixed(q == q.roundToDouble() ? 0 : 3)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');

  String _sourceLabel(ProductionItemSource s) => switch (s) {
        ProductionItemSource.recipeDefault => 'dari resep',
        ProductionItemSource.invoice => 'dari invoice',
        ProductionItemSource.manual => 'manual',
      };
}
