import 'package:flutter/material.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'paged_sliver_list.dart';

/// Body view yang otomatis switch antara loading / error / empty / data
/// berdasarkan state. Membungkus [RefreshIndicator] + [CustomScrollView]
/// agar pull-to-refresh berfungsi di **semua** kondisi.
///
/// Mendukung [sliverHeader] opsional (e.g., search field, filter chips)
/// yang dirender SEBELUM list dan scroll bareng list.
///
/// Contoh pemakaian:
/// ```dart
/// PagedBodyView<Order>(
///   isLoading: provider.isLoading,
///   error: provider.error,
///   items: provider.orders,
///   hasMore: provider.hasMore,
///   onRefresh: provider.loadInitial,
///   onLoadMore: provider.loadMore,
///   sliverHeader: SliverToBoxAdapter(child: SearchField()),
///   itemBuilder: (ctx, i) => OrderCard(provider.orders[i]),
///   emptyIcon: Icons.local_shipping_outlined,
///   emptyTitle: 'Belum ada order',
/// )
/// ```
class PagedBodyView<T> extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<T> items;
  final Widget Function(BuildContext, int) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;

  /// Header sliver opsional. Dirender SEBELUM list di CustomScrollView.
  /// Contoh: `SliverToBoxAdapter(child: searchField)`.
  final Widget? sliverHeader;

  // Empty state config.
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  // Error state config.
  final VoidCallback? onRetry;

  final EdgeInsets? padding;
  final ScrollController? controller;
  final double loadMoreThreshold;

  /// Builder custom untuk loading footer saat loadMore.
  final Widget Function(BuildContext)? loadingMoreBuilder;

  const PagedBodyView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
    this.onLoadMore,
    this.hasMore = false,
    this.sliverHeader,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Belum ada data.',
    this.emptySubtitle,
    this.onRetry,
    this.padding,
    this.controller,
    this.loadMoreThreshold = 200,
    this.loadingMoreBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Initial loading — spinner tanpa pull-to-refresh.
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Error state — pakai ErrorState, tapi tetap bungkus RefreshIndicator
    //    agar pull-to-refresh berfungsi untuk retry tanpa tap tombol.
    if (error != null && items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            ErrorState(
              message: error!,
              onRetry: onRetry ?? onRefresh,
            ),
          ],
        ),
      );
    }

    // 3. Empty / Data — selalu RefreshIndicator + CustomScrollView (sliver).
    final isEmpty = items.isEmpty && !isLoading;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (sliverHeader != null)
            if (padding != null)
              SliverPadding(
                padding: EdgeInsets.only(
                  top: padding!.top,
                  left: padding!.left,
                  right: padding!.right,
                ),
                sliver: sliverHeader!,
              )
            else
              sliverHeader!,
          if (padding != null)
            SliverPadding(
              padding: EdgeInsets.only(
                top: sliverHeader != null ? 0 : padding!.top,
                bottom: padding!.bottom,
                left: padding!.left,
                right: padding!.right,
              ),
              sliver: _buildContentSliver(isEmpty),
            )
          else
            _buildContentSliver(isEmpty),
        ],
      ),
    );
  }

  Widget _buildContentSliver(bool isEmpty) {
    if (isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: emptyIcon,
          title: emptyTitle,
          subtitle: emptySubtitle,
        ),
      );
    }

    return PagedSliverList<T>(
      items: items,
      itemBuilder: itemBuilder,
      hasMore: hasMore,
      onLoadMore: onLoadMore ?? () async {},
      controller: controller,
      loadMoreThreshold: loadMoreThreshold,
      loadingMoreBuilder: loadingMoreBuilder,
    );
  }
}
