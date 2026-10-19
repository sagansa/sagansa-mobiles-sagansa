import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/enums/import_stage.dart';
import '../models/import_model.dart';
import '../services/import_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import 'import_detail_page.dart';
import 'import_form_page.dart';

/// Daftar proses impor barang + filter tahap.
///
/// Entry dari menu Transaksi (admin/super_admin); baca dibuka untuk semua
/// user login.
class ImportListPage extends StatefulWidget {
  const ImportListPage({super.key});

  @override
  State<ImportListPage> createState() => _ImportListPageState();
}

class _ImportListPageState extends State<ImportListPage> {
  final ImportService _service = ImportService();
  final NumberFormat _money = NumberFormat('#,##0');

  List<ImportPurchase> _imports = [];
  Map<String, int> _stageCounts = {};
  String? _selectedStage;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.getImports(
        perPage: 100,
        stage: _selectedStage,
      );
      if (!mounted) return;
      setState(() {
        _imports = result['data'] as List<ImportPurchase>;
        _stageCounts =
            Map<String, int>.from(result['stage_counts'] as Map<String, int>);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Impor Barang',
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: _imports.isEmpty && !_isLoading && _error == null,
      emptyState: EmptyState(
        icon: Icons.public_outlined,
        title: _selectedStage == null
            ? 'Belum ada proses impor'
            : 'Tidak ada proses di tahap ini',
        subtitle: 'Tekan tombol + untuk membuat proses impor baru (draft).',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Impor baru',
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageFilter(),
          AppSpacing.gapVerticalMD,
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildStageFilter() {
    final stages = [
      ...ImportStage.flow,
      ImportStage.cancelled,
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stages.length,
        separatorBuilder: (_, __) => AppSpacing.gapHorizontalSM,
        itemBuilder: (context, i) {
          final stage = stages[i];
          final selected = _selectedStage == stage.name;
          final count = _stageCounts[stage.name] ?? 0;

          return FilterChip(
            selected: selected,
            label: Text('${stage.displayLabel} ($count)'),
            onSelected: (_) {
              setState(() {
                _selectedStage = selected ? null : stage.name;
              });
              _load();
            },
          );
        },
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _imports.length,
        separatorBuilder: (_, __) => AppSpacing.gapVerticalSM,
        itemBuilder: (context, i) => _buildCard(_imports[i]),
      ),
    );
  }

  Widget _buildCard(ImportPurchase import) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () => _openDetail(import.id),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.public_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.gapHorizontalSM,
                  Expanded(
                    child: Text(
                      import.supplierName,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(
                    label: import.stage.displayLabel,
                    type: import.stage.badgeType,
                  ),
                ],
              ),
              AppSpacing.gapVerticalSM,
              Text(
                '${import.items.length} produk • kurs ${_money.format(import.exchangeRate)} • ${import.currency}',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              AppSpacing.gapVerticalSM,
              Row(
                children: [
                  Expanded(
                    child: _total('Estimasi', import.totalEstimate),
                  ),
                  AppSpacing.gapHorizontalMD,
                  Expanded(
                    child: _total('Realisasi', import.totalReal),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _total(String label, double value) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        Text(
          'Rp ${_money.format(value)}',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _openForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ImportFormPage()),
    );
    if (created == true) _load();
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportDetailPage(importId: id),
      ),
    );
    if (changed == true) _load();
  }
}
