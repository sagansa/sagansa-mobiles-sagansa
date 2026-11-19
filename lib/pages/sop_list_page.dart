import 'package:flutter/material.dart';

import '../models/sop_model.dart';
import '../services/sop_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/search_text_field.dart';
import 'home_page.dart';
import 'hrd_dashboard_page.dart';
import 'sop_detail_page.dart';
import 'stock_dashboard_page.dart';
import 'transaction_dashboard_page.dart';

/// Daftar panduan SOP: filter kategori + pencarian + infinite scroll.
class SopListPage extends StatefulWidget {
  const SopListPage({super.key});

  @override
  State<SopListPage> createState() => _SopListPageState();
}

class _SopListPageState extends State<SopListPage> {
  final SopService _service = SopService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<SopCategoryModel> _categories = [];
  List<SopModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  String? _errorMessage;

  SopCategoryModel? _selectedCategory;
  String? _query;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _fetch();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
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

  void _handleNavigation(BuildContext context, int index) {
    if (index == 4) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const HomePage()));
        break;
      case 1:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const HRDDashboardPage()));
        break;
      case 2:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const StockDashboardPage()));
        break;
      case 3:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const TransactionDashboardPage()));
        break;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _service.getCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      // Kategori gagal dimuat tidak menghalangkan daftar SOP ("Semua").
    }
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _items = [];
      _hasMore = true;
    });
    try {
      final result = await _service.getSops(
        categoryId: _selectedCategory?.id,
        query: _query,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items = result['data'] as List<SopModel>;
        _hasMore = result['has_more'] as bool;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.getSops(
        categoryId: _selectedCategory?.id,
        query: _query,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result['data'] as List<SopModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _applySearch(String value) {
    _query = value.trim().isEmpty ? null : value.trim();
    _fetch();
  }

  void _selectCategory(SopCategoryModel? category) {
    setState(() => _selectedCategory = category);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPageScaffold(
      titleText: 'Panduan SOP',
      actions: [
        BarButtonCluster(
          actions: [
            BarButtonSpec(
              icon: _isSearchActive
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
              iconSize: 22,
              tooltip: _isSearchActive ? 'Tutup Pencarian' : 'Cari SOP',
              onTap: () {
                setState(() {
                  _isSearchActive = !_isSearchActive;
                  if (!_isSearchActive) {
                    _searchController.clear();
                    _query = null;
                    _fetch();
                  }
                });
              },
            ),
          ],
        ),
      ],
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 4,
        onTap: (index) => _handleNavigation(context, index),
      ),
      bodyPadding: EdgeInsets.zero,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            if (_isSearchActive) _buildSearchRow(colorScheme),
            if (_categories.isNotEmpty) _buildCategoryChips(colorScheme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? EmptyState(
                          icon: Icons.error_outline_rounded,
                          title: _errorMessage!,
                          subtitle: 'Terjadi kesalahan saat memuat data',
                          action: ElevatedButton.icon(
                            onPressed: _fetch,
                            style: AppButtonStyle.elevated(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba Lagi'),
                          ),
                        )
                      : !_hasLoaded
                          ? const Center(child: CircularProgressIndicator())
                          : _items.isEmpty
                              ? EmptyState(
                                  icon: Icons.menu_book_outlined,
                                  title: _query != null
                                      ? 'Tidak ada SOP yang cocok dengan pencarian.'
                                      : 'Belum ada panduan SOP.',
                                  subtitle: _query != null
                                      ? 'Coba kata kunci lain atau hapus filter.'
                                      : 'SOP yang diterbitkan admin akan tampil di sini.',
                                )
                              : _buildList(colorScheme, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: SearchTextField(
        controller: _searchController,
        hintText: 'Cari judul SOP...',
        onSubmitted: _applySearch,
        onCleared: () => _applySearch(''),
      ),
    );
  }

  Widget _buildCategoryChips(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: FilterChipRow<SopCategoryModel?>(
        options: [null, ..._categories],
        selected: _selectedCategory,
        onSelected: _selectCategory,
        getLabel: (category) => category?.name ?? 'Semua',
      ),
    );
  }

  Widget _buildList(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        controller: _scrollController,
        // SafeArea(top) di body sudah menghitung status bar + appbar;
        // padding atas cukup kecil agar tidak terjadi inset ganda.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.md,
          ModernBottomNav.clearance(context),
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildCard(_items[idx], colorScheme, textTheme);
        },
      ),
    );
  }

  Widget _buildCard(
      SopModel item, ColorScheme colorScheme, TextTheme textTheme) {
    final coverUrl = item.coverImageUrl;
    final stepCount = item.totalStepCount;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SopDetailPage(sopId: item.id)),
          );
        },
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(coverUrl, colorScheme, 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.description!,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.category_outlined,
                            size: 13, color: colorScheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            [
                              if (item.categoryName != null)
                                item.categoryName!,
                              if (stepCount > 0)
                                '$stepCount langkah',
                              'Rev ${item.revision}',
                            ].join(' • '),
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(String? url, ColorScheme colorScheme, double size) {
    if (url == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: AppSpacing.borderRadiusSM,
        ),
        child: Icon(Icons.menu_book_rounded, color: colorScheme.primary),
      );
    }
    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusSM,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(Icons.menu_book_rounded, color: colorScheme.primary),
        ),
      ),
    );
  }
}
