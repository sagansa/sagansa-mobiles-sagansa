import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../models/last_order_user_model.dart';
import '../services/last_order_user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/whatsapp_utils.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/email_action_row.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import 'admin_last_order_user_detail_page.dart';

/// Daftar "kapan terakhir user order" — khusus admin/super_admin.
/// Filter (pencarian, urutan, punya no telp) lewat pill kanan-atas
/// (pola admin_profile_list_page), kartu bisa ditap untuk detail user,
/// chip no telp membuka WhatsApp (wa.me).
class AdminLastOrderUserListPage extends StatefulWidget {
  const AdminLastOrderUserListPage({
    super.key,
    this.service,
    this.launchUrlImpl,
  });

  /// Injection untuk widget test; null = pakai service sungguhan.
  final LastOrderUserService? service;

  /// Injection launcher WhatsApp untuk widget test; null = url_launcher.
  final Future<void> Function(Uri url)? launchUrlImpl;

  @override
  State<AdminLastOrderUserListPage> createState() =>
      _AdminLastOrderUserListPageState();
}

class _AdminLastOrderUserListPageState extends State<AdminLastOrderUserListPage> {
  late final LastOrderUserService _service;
  late final Future<void> Function(Uri url) _launchUrl;

  final ScrollController _scrollController = ScrollController();

  final List<LastOrderUserModel> _list = [];
  int _page = 1;
  bool _hasNext = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  bool _isAdmin = false;

  // State filter (dikelola lewat FilterBottomSheet).
  String? _search;
  String _sort = 'last_order_desc'; // 'last_order_desc' | 'last_order_asc'
  bool _hasPhone = false;

  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LastOrderUserService();
    _launchUrl = widget.launchUrlImpl ??
        (Uri url) => url_launcher.launchUrl(
              url,
              mode: url_launcher.LaunchMode.externalApplication,
            );
    _scrollController.addListener(_onScroll);
    _loadRoles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Guard page (defense-in-depth — tile Transaksi disembunyikan utk non-admin).
  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    var roles = const <String>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          roles = List<String>.from(decoded['roles'] ?? []);
        }
      } catch (_) {
        // Data prefs rusak — anggap bukan admin.
      }
    }
    final isAdmin = roles.contains('admin') || roles.contains('super_admin');
    if (!mounted) return;
    setState(() => _isAdmin = isAdmin);
    if (isAdmin) {
      _loadFirst();
    } else {
      setState(() => _isLoading = false);
    }
  }

  bool get _hasActiveFilter =>
      (_search != null && _search!.trim().isNotEmpty) || _hasPhone;

  int get _activeFilterCount =>
      ((_search != null && _search!.trim().isNotEmpty) ? 1 : 0) +
      (_hasPhone ? 1 : 0);

  Future<void> _loadFirst() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final (list, hasNext) = await _service.getList(
        page: 1,
        perPage: _perPage,
        search: _search,
        sort: _sort,
        hasPhone: _hasPhone ? true : null,
      );
      if (!mounted) return;
      setState(() {
        _list
          ..clear()
          ..addAll(list);
        _page = 1;
        _hasNext = hasNext;
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
    if (_isLoadingMore || !_hasNext || _isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final (list, hasNext) = await _service.getList(
        page: _page + 1,
        perPage: _perPage,
        search: _search,
        sort: _sort,
        hasPhone: _hasPhone ? true : null,
      );
      if (!mounted) return;
      setState(() {
        _list.addAll(list);
        _page += 1;
        _hasNext = hasNext;
      });
    } catch (_) {
      // Load-more gagal diam-diam; user bisa scroll ulang atau refresh.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter & Pencarian',
      fields: [
        TextFilterField(
          label: 'Pencarian',
          value: _search,
          hint: 'Nama, email, atau no telp...',
        ),
        ChipFilterField<String>(
          label: 'Urutan',
          value: _sort,
          options: const [
            ('last_order_desc', 'Terbaru'),
            ('last_order_asc', 'Terlama'),
          ],
        ),
        ChipFilterField<bool>(
          label: 'No Telp',
          value: _hasPhone ? true : null,
          options: const [(true, 'Punya no telp')],
        ),
      ],
      onApply: (values) {
        setState(() {
          _search = values['Pencarian'] as String?;
          _sort = (values['Urutan'] as String?) ?? 'last_order_desc';
          _hasPhone = values['No Telp'] == true;
        });
        _loadFirst();
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _search = null;
      _sort = 'last_order_desc';
      _hasPhone = false;
    });
    _loadFirst();
  }

  Future<void> _openDetail(LastOrderUserModel item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminLastOrderUserDetailPage(
          userId: item.userId,
          service: widget.service,
          launchUrlImpl: widget.launchUrlImpl,
        ),
      ),
    );
    // Refresh marker follow-up setelah kembali dari detail.
    if (mounted) _loadFirst();
  }

  Future<void> _openWhatsApp(String phone) async {
    final uri = WhatsAppUtils.chatUri(phone);
    if (uri == null) return;
    try {
      await _launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka WhatsApp: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Order Terakhir User'),
        actions: [
          BarButtonCluster(actions: [
            if (_hasActiveFilter)
              BarButtonSpec(
                icon: Icons.filter_list_off,
                tooltip: 'Hapus Filter',
                onTap: _clearFilters,
              ),
            BarButtonSpec(
              icon: Icons.tune,
              tooltip: 'Filter & Pencarian',
              badgeCount: _activeFilterCount,
              onTap: _openFilterSheet,
            ),
          ]),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: !_isAdmin
            ? _buildEmptyState(
                theme,
                Icons.lock_outline,
                'Halaman ini khusus admin.',
              )
            : _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapVerticalMD,
              FilledButton(
                onPressed: _loadFirst,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (_list.isEmpty) {
      return _buildEmptyState(
        theme,
        Icons.person_search_outlined,
        _hasActiveFilter
            ? 'Tidak ada user yang cocok dengan filter.'
            : 'Belum ada user dengan order direct.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        itemCount: _list.length + (_hasNext ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _list.length) {
            return _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildItem(theme, _list[index]),
          );
        },
      ),
    );
  }

  /// Empty/guard state — pola `admin_profile_list_page`: icon besar redup,
  /// pesan, dan aksi kontekstual.
  Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            AppSpacing.gapVerticalSM,
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Baris user — gabungan pola kartu `admin_profile_list_page` (judul bold,
  /// email, pill status berwarna) dan `_OrderTile` `sales_order_employee_list_page`
  /// (meta baris ber-icon kecil).
  Widget _buildItem(ThemeData theme, LastOrderUserModel item) {
    final dateText = item.lastOrderAt != null
        ? FormatUtils.formatDate(item.lastOrderAt!)
        : '-';
    return Card(
      elevation: AppElevation.level1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(item),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.lastOrderAt != null) ...[
                    AppSpacing.gapHorizontalSM,
                    _recencyPill(theme, item.lastOrderAt!),
                  ],
                ],
              ),
              AppSpacing.gapVerticalXS,
              if (item.email != null)
                EmailActionRow(
                  email: item.email!,
                  launchUrlImpl: widget.launchUrlImpl,
                )
              else
                Text(
                  'Tanpa email',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              if (item.phones.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final p in item.phones) _buildPhoneChip(theme, p),
                  ],
                ),
              ],
              if (item.lastFollowUpAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 13, color: AppColors.success),
                    AppSpacing.gapHorizontalXS,
                    Expanded(
                      child: Text(
                        'Dihubungi ${FormatUtils.formatDate(item.lastFollowUpAt!)}'
                        ' • ${item.lastFollowUpByName ?? '-'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.success),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _metaRow(theme, Icons.calendar_today_outlined,
                  'Terakhir order: $dateText'),
              const SizedBox(height: 2),
              _metaRow(
                theme,
                Icons.payments_outlined,
                'Total: ${FormatUtils.formatCurrency(item.totalNominal)} '
                    '(${item.totalOrders} order)',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill jarak waktu sejak order terakhir — pola pill status
  /// `admin_profile_list_page`. Warna = urgensi follow-up:
  /// ≤14 hari hijau (masih aktif), 15–60 oranye (menurun), >60 merah.
  Widget _recencyPill(ThemeData theme, DateTime lastOrderAt) {
    final days = DateTime.now().difference(lastOrderAt).inDays;
    final Color color;
    if (days <= 14) {
      color = AppColors.success;
    } else if (days <= 60) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Text(
        _relativeDayText(days),
        style: theme.textTheme.labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _relativeDayText(int days) {
    if (days <= 0) return 'Hari ini';
    if (days == 1) return 'Kemarin';
    if (days < 30) return '$days hari lalu';
    if (days < 365) return '${days ~/ 30} bln lalu';
    return '${days ~/ 365} thn lalu';
  }

  Widget _metaRow(ThemeData theme, IconData icon, String text) {
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        AppSpacing.gapHorizontalXS,
        Expanded(
          child: Text(
            text,
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneChip(ThemeData theme, String phone) {
    final uri = WhatsAppUtils.chatUri(phone);
    return ActionChip(
      avatar: Icon(
        Icons.chat_bubble,
        size: 16,
        color: uri == null
            ? theme.disabledColor
            : const Color(0xFF25D366), // WhatsApp Green
      ),
      label: Text(phone),
      onPressed: uri == null ? null : () => _openWhatsApp(phone),
    );
  }
}
