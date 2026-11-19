import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/production_model.dart';
import '../providers/auth_provider.dart';
import '../services/production_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import 'production_detail_page.dart';
import 'production_form_page.dart';

/// Daftar produksi (admin/super_admin only — backend yang validasi role).
/// Mendukung infinite scroll + filter status/applied via chips di atas.
class ProductionListPage extends StatefulWidget {
  const ProductionListPage({super.key});

  @override
  State<ProductionListPage> createState() => _ProductionListPageState();
}

class _ProductionListPageState extends State<ProductionListPage> {
  final ProductionService _service = ProductionService();
  final ScrollController _scrollController = ScrollController();

  final List<Production> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  // Filter state.
  String? _statusFilter; // null = semua
  bool? _appliedFilter; // null = semua

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = reset;
      _isLoadingMore = !reset;
      _error = null;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
      }
    });

    try {
      final result = await _service.list(
        page: _page,
        status: _statusFilter,
        applied: _appliedFilter,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.nextPage != null;
        if (result.nextPage != null) _page = result.nextPage!;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() => _load(reset: false);

  Future<void> _refresh() => _load(reset: true);

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductionFormPage()),
    );
    if (created == true) _refresh();
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductionDetailPage(id: id)),
    );
    if (changed == true) _refresh();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_statusFilter != null) count++;
    if (_appliedFilter != null) count++;
    return count;
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter',
      fields: [
        DropdownFilterField<String?>(
          label: 'Status',
          value: _statusFilter,
          options: const [
            (null, 'Semua'),
            ('1', 'Belum diperiksa'),
            ('2', 'Valid'),
            ('3', 'Perbaiki'),
          ],
        ),
        DropdownFilterField<bool?>(
          label: 'Stok',
          value: _appliedFilter,
          options: const [
            (null, 'Semua Stok'),
            (false, 'Belum diterapkan'),
            (true, 'Sudah diterapkan'),
          ],
        ),
      ],
      onApply: (values) {
        setState(() {
          _statusFilter = values['Status'] as String?;
          _appliedFilter = values['Stok'] as bool?;
        });
        _load(reset: true);
      },
      onReset: () {
        setState(() {
          _statusFilter = null;
          _appliedFilter = null;
        });
        _load(reset: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Produksi'),
        actions: [
          BarButtonCluster(actions: [
            BarButtonSpec(
              icon: Icons.tune,
              tooltip: 'Filter',
              badgeCount: _activeFilterCount,
              onTap: _openFilterSheet,
            ),
            // Backend hanya mengizinkan admin/super_admin membuat produksi
            // (authorizeAdmin) — tombol create hanya untuk role tersebut.
            if (isAdmin)
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Produksi',
                onTap: _openCreate,
              ),
          ]),
        ],
      ),
      body: _buildBody(isAdmin),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildBody(bool isAdmin) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            AppSpacing.gapVerticalMD,
            FilledButton(onPressed: _refresh, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.only(top: AppBarInsets.top(context)),
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.factory_outlined,
                        size: 64, color: Theme.of(context).colorScheme.outline),
                    AppSpacing.gapVerticalMD,
                    const Text('Belum ada produksi.'),
                    if (isAdmin) ...[
                      AppSpacing.gapVerticalSM,
                      FilledButton.tonalIcon(
                        onPressed: _openCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('Buat Produksi'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: AppSpacing.paddingMD.copyWith(
          top: AppBarInsets.top(context),
          bottom: ModernBottomNav.clearance(context),
        ),
        itemCount: _items.length + 1,
        itemBuilder: (ctx, i) {
          if (i == _items.length) {
            return _hasMore
                ? const Padding(
                    padding: AppSpacing.paddingMD,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }
          final p = _items[i];
          return _buildTile(p);
        },
      ),
    );
  }

  Widget _buildTile(Production p) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: () => _openDetail(p.id),
        title: Row(
          children: [
            Expanded(
              child: Text(
                p.recipe?.product.name ?? 'Produksi Manual',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (p.isApplied)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: Text(
                  'Stok diterapkan',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${p.store?.nickname ?? '-'} · ${FormatUtils.formatDate(p.date)} · ${p.statusLabel}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${p.items.where((i) => i.direction == ProductionItemDirection.output).length} out',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '${p.items.where((i) => i.direction == ProductionItemDirection.input).length} in',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
