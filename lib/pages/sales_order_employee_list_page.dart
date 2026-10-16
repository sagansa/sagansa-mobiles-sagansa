import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_order_employee_model.dart';
import '../services/sales_order_employee_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_dropdown.dart';
import 'sales_order_employee_detail_page.dart';
import 'sales_order_employee_form_page.dart';

/// List penjualan employee (for=2).
///
/// - Role `sales`: melihat miliknya sendiri, FAB "+" untuk create.
/// - Role `admin/super_admin`: melihat SEMUA order, dengan filter per sales.
class SalesOrderEmployeeListPage extends StatefulWidget {
  /// Set false saat di-embed di [SalesHomePage] agar tidak muncul AppBar
  /// ganda (halaman induk sudah punya AppBar + tab bar).
  final bool showAppBar;

  const SalesOrderEmployeeListPage({super.key, this.showAppBar = true});

  @override
  State<SalesOrderEmployeeListPage> createState() =>
      SalesOrderEmployeeListPageState();
}

/// Public supaya induk (mis. [SalesHomePage]) bisa memanggil [openCreate]
/// via `GlobalKey<SalesOrderEmployeeListPageState>` — pola yang sama dengan
/// `_EmployeeTabContentState` di sales_page.dart.
class SalesOrderEmployeeListPageState
    extends State<SalesOrderEmployeeListPage> {
  final SalesOrderEmployeeService _service = SalesOrderEmployeeService();
  final ScrollController _scrollController = ScrollController();

  List<SalesOrderEmployeeModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  String? _error;

  bool _isAdmin = false;
  bool _isSales = false;

  /// Daftar sales untuk filter admin. Map id -> name.
  Map<int, String> _salesOptions = {};
  int? _selectedSalesId;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadData();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final userData = json.decode(userString);
      final roles = List<String>.from(userData['roles'] ?? []);
      if (mounted) {
        setState(() {
          _isAdmin = roles.contains('admin') || roles.contains('super_admin');
          _isSales = roles.contains('sales');
        });
      }
    }
  }

  Future<void> _loadData({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final (list, hasNext) = await _service.getList(
        salesId: _selectedSalesId,
        page: _page,
      );
      if (!mounted) return;

      // Bangun opsi filter sales dari response (untuk admin).
      if (_isAdmin) {
        final newOptions = <int, String>{};
        for (final o in [..._items, ...list]) {
          if (o.orderedByName != null) {
            newOptions[o.orderedById] = o.orderedByName!;
          }
        }
        _salesOptions = newOptions;
      }

      setState(() {
        _items = reset ? list : [..._items, ...list];
        _hasNext = hasNext;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.sanitize(e);
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasNext || _isLoadingMore) return;
    _page += 1;
    await _loadData(reset: false);
  }

  /// Buka form create, lalu refresh list jika ada order baru.
  /// Public supaya bisa dipanggil dari AppBar induk saat halaman ini
  /// di-embed dengan `showAppBar: false`.
  Future<void> openCreate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => const SalesOrderEmployeeFormPage()),
    );
    if (result == true) _loadData();
  }

  Future<void> _openDetail(SalesOrderEmployeeModel order) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SalesOrderEmployeeDetailPage(orderId: order.id, canEdit: _isSales),
      ),
    );
    if (changed == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: widget.showAppBar
          ? GlassAppBar(
              title: const Text('Penjualan Employee'),
              actions: [
                if (_isSales)
                  BarButtonCluster(
                    actions: [
                      BarButtonSpec(
                        icon: Icons.add_rounded,
                        iconSize: 22,
                        tooltip: 'Tambah Order Employee',
                        onTap: _isLoading ? null : openCreate,
                      ),
                    ],
                  ),
              ],
            )
          : null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            if (_isAdmin) _buildSalesFilter(theme, colorScheme),
            Expanded(child: _buildBody(theme, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesFilter(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: ModernDropdown<int?>(
        value: _selectedSalesId,
        labelText: 'Filter per Sales',
        hint: 'Semua Sales',
        prefixIcon: const Icon(Icons.person_outline, size: 20),
        items: [null, ..._salesOptions.keys],
        getLabel: (v) {
          if (v == null) return 'Semua Sales';
          return _salesOptions[v] ?? 'Sales #$v';
        },
        onChanged: (v) {
          if (v == _selectedSalesId) return;
          setState(() => _selectedSalesId = v);
          _loadData();
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              AppSpacing.gapVerticalSM,
              FilledButton(
                onPressed: () => _loadData(),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Text(
            'Belum ada penjualan employee.',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: ListView.separated(
          controller: _scrollController,
      padding: AppSpacing.paddingHorizontalMD,
      itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) {
            if (index == _items.length) {
              return _isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }
            final o = _items[index];
            return _OrderTile(
              order: o,
              showSales: _isAdmin,
              onTap: () => _openDetail(o),
            );
          },
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final SalesOrderEmployeeModel order;
  final bool showSales;
  final VoidCallback onTap;
  const _OrderTile(
      {required this.order, required this.showSales, required this.onTap});

  Color _statusColor(ColorScheme cs) {
    switch (order.paymentStatus) {
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.error;
      case 4:
        return AppColors.warning;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Widget _thumb(ColorScheme cs) {
    final url = order.imagePaymentUrl;
    if (url == null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: AppSpacing.borderRadiusMD,
        ),
        child: Icon(Icons.receipt_long_outlined,
            color: cs.onSurfaceVariant, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusMD,
      child: Image.network(
        url,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          child: Icon(Icons.receipt_long_outlined,
              color: cs.onSurfaceVariant, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateText = order.deliveryDate != null
        ? FormatUtils.formatDate(order.deliveryDate!)
        : '-';
    final itemCount = order.items.length;
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final statusColor = _statusColor(cs);

    return Card(
      elevation: AppElevation.level1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(cs),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.deliveryAddressName ??
                          order.storeName ??
                          'Customer',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapVerticalXS,
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        AppSpacing.gapHorizontalXS,
                        Expanded(
                          child: Text(
                            dateText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (showSales && order.orderedByName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13, color: cs.onSurfaceVariant),
                          AppSpacing.gapHorizontalXS,
                          Expanded(
                            child: Text(
                              order.orderedByName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (firstItem != null)
                          _Chip(
                            icon: Icons.inventory_2_outlined,
                            label: itemCount > 1
                                ? '${firstItem.productName} +${itemCount - 1}'
                                : firstItem.productName,
                          ),
                        if (order.storeName != null)
                          _Chip(
                            icon: Icons.store_outlined,
                            label: order.storeName!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.formatCurrency(order.totalPrice),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: AppSpacing.borderRadiusSM,
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.paymentStatus == 2
                              ? Icons.check_circle_outline
                              : order.paymentStatus == 3
                                  ? Icons.cancel_outlined
                                  : Icons.pending_outlined,
                          size: 12,
                          color: statusColor,
                        ),
                        AppSpacing.gapHorizontalXS,
                        Text(
                          order.paymentStatusLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppSpacing.borderRadiusSM,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          AppSpacing.gapHorizontalXS,
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
