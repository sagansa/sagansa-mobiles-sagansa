import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transfer_stock_model.dart';
import '../providers/auth_provider.dart';
import '../services/transfer_stock_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'create_transfer_stock_page.dart';
import 'transfer_stock_detail_page.dart';

class TransferStockListPage extends StatefulWidget {
  const TransferStockListPage({super.key});

  @override
  State<TransferStockListPage> createState() => _TransferStockListPageState();
}

class _TransferStockListPageState extends State<TransferStockListPage> {
  final TransferStockService _service = TransferStockService();
  final ScrollController _scrollController = ScrollController();

  List<TransferStockModel> _transfers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTransfers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (!_isLoadingMore && _hasMore) _loadMore();
      });
    }
  }

  Future<void> _fetchTransfers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _transfers = [];
      _hasMore = true;
    });

    try {
      final result = await _service.getTransferStocks(page: _page);
      if (!mounted) return;
      setState(() {
        _transfers = result['transfers'] as List<TransferStockModel>;
        _hasMore = result['has_more'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.getTransferStocks(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _transfers.addAll(result['transfers'] as List<TransferStockModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  StatusType _statusType(int status) {
    switch (status) {
      case 1:
        return StatusType.warning;
      case 2:
        return StatusType.success;
      case 3:
        return StatusType.info;
      case 4:
        return StatusType.error;
      default:
        return StatusType.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppPageScaffold(
      titleText: 'Transfer Stok',
      actions: [
        BarButtonCluster(
          actions: [
            if (!context.watch<AuthProvider>().isAdmin)
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Transfer Stok',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateTransferStockPage(),
                    ),
                  );
                  if (result == true) {
                    _fetchTransfers();
                  }
                },
              ),
          ],
        ),
      ],
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRetry: _fetchTransfers,
      isEmpty: _transfers.isEmpty,
      emptyState: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              size: 48,
              color: AppColors.info.withValues(alpha: 0.5),
            ),
            AppSpacing.gapVerticalMD,
            Text(
              'Belum ada riwayat transfer stok.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      bodyPadding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: _fetchTransfers,
        child: ListView.builder(
          controller: _scrollController,
          padding: AppSpacing.paddingMD.copyWith(
            top: AppBarInsets.top(context) + 8,
            bottom: ModernBottomNav.clearance(context) + 16,
          ),
          itemCount: _transfers.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, idx) {
            if (idx == _transfers.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final transfer = _transfers[idx];

            return _buildTransferCard(
                context, transfer, theme, colorScheme);
          },
        ),
      ),
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

  Widget _buildTransferCard(
    BuildContext context,
    TransferStockModel transfer,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final textTheme = theme.textTheme;
    final detailsCount = transfer.details.length;
    final previewNames = transfer.details
        .take(2)
        .map((d) => d.productName)
        .where((n) => n.isNotEmpty)
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      elevation: 0,
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TransferStockDetailPage(transferId: transfer.id),
            ),
          );
          _fetchTransfers();
        },
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Stores Transfer Route & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            transfer.fromStoreName.isNotEmpty
                                ? transfer.fromStoreName
                                : 'Gudang/Toko',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            transfer.toStoreName.isNotEmpty
                                ? transfer.toStoreName
                                : 'Tujuan',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalSM,
                  StatusBadge(
                    label: transfer.statusText,
                    type: _statusType(transfer.status),
                    size: BadgeSize.small,
                  ),
                ],
              ),
              AppSpacing.gapVerticalSM,

              // Date & ID Row
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${transfer.date} • #${transfer.id}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVerticalXS,

              // Sender / Receiver Row
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Kirim: ${transfer.sentByName}${transfer.receivedByName != null ? ' • Terima: ${transfer.receivedByName}' : ''}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const Divider(height: 18),

              // Bottom Row: Item count & items summary preview
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppSpacing.borderRadiusSM,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$detailsCount item',
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (previewNames.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        previewNames,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
