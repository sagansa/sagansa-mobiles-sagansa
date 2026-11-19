import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/readiness_model.dart';
import '../services/readiness_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/empty_state.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'home_page.dart';
import 'hrd_dashboard_page.dart';
import 'readiness_detail_page.dart';
import 'readiness_page.dart';
import 'stock_dashboard_page.dart';
import 'transaction_dashboard_page.dart';

class ReadinessListPage extends StatefulWidget {
  const ReadinessListPage({super.key});

  @override
  State<ReadinessListPage> createState() => _ReadinessListPageState();
}

class _ReadinessListPageState extends State<ReadinessListPage> {
  final ReadinessService _service = ReadinessService();
  final ScrollController _scrollController = ScrollController();

  List<ReadinessModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Mode admin (lihat semua karyawan + filter tanggal); role lain lihat milik sendiri.
  bool _isAdmin = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final roles = List<String>.from(json.decode(userString)['roles'] ?? []);
      _isAdmin = roles.contains('admin') || roles.contains('super_admin');
    }
    if (!mounted) return;
    _fetch();
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
      final result = _isAdmin
          ? await _service.getAdminList(
              page: _page,
              date:
                  _selectedDate != null ? _formatIsoDate(_selectedDate!) : null,
            )
          : await _service.getHistory(page: _page);
      if (!mounted) return;
      setState(() {
        _items = result['data'] as List<ReadinessModel>;
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
      final result = _isAdmin
          ? await _service.getAdminList(
              page: _page + 1,
              date:
                  _selectedDate != null ? _formatIsoDate(_selectedDate!) : null,
            )
          : await _service.getHistory(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result['data'] as List<ReadinessModel>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  String _formatIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _formatDisplayDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetch();
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPageScaffold(
      titleText: 'Kesiapan Diri',
      actions: [
        BarButtonCluster(
          actions: [
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: 'Tambah Kesiapan Diri',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReadinessPage()),
                );
                _fetch();
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
          if (_isAdmin) _buildFilterRow(textTheme, colorScheme),
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
                            ? const EmptyState(
                                icon: Icons.checkroom_outlined,
                                title: 'Belum ada laporan kesiapan diri.',
                              )
                            : _buildList(colorScheme, textTheme),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(_selectedDate != null
                  ? _formatDisplayDate(_selectedDate!)
                  : 'Semua tanggal'),
            ),
          ),
          if (_selectedDate != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: _clearDate,
              icon: const Icon(Icons.clear),
              tooltip: 'Tampilkan semua tanggal',
            ),
          ] else ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${_items.length} entri',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
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
          return _buildCard(_items[idx], idx, colorScheme, textTheme);
        },
      ),
    );
  }

  Widget _buildCard(ReadinessModel item, int idx, ColorScheme colorScheme,
      TextTheme textTheme) {
    final name = item.createdByName ?? 'Tanpa nama';

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
        onTap: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReadinessDetailPage(
                items: _items,
                initialIndex: idx,
                isAdmin: _isAdmin,
              ),
            ),
          );
          if (changed == true) _fetch();
        },
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _thumb(item.selfieUrl, Icons.face, colorScheme, 52),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            StatusBadge(
                              label: item.statusLabel,
                              type: _statusType(item.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 13, color: AppColors.info),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _formatDate(item.createdAt),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _labeledPhoto('Tangan Kiri', item.leftHandUrl,
                        Icons.back_hand, colorScheme, textTheme),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _labeledPhoto('Tangan Kanan', item.rightHandUrl,
                        Icons.front_hand, colorScheme, textTheme),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  StatusType _statusType(int? status) =>
      status == 2 ? StatusType.success : StatusType.warning;

  Widget _labeledPhoto(String label, String? url, IconData icon,
      ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppSpacing.borderRadiusSM,
          child: url == null
              ? Container(
                  height: 72,
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  child: Center(child: Icon(icon, color: AppColors.info)),
                )
              : Image.network(
                  url,
                  height: 72,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 72,
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    child: Center(child: Icon(icon, color: AppColors.info)),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _thumb(
      String? url, IconData icon, ColorScheme colorScheme, double size) {
    if (url == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: AppSpacing.borderRadiusSM,
        ),
        child: Icon(icon, color: AppColors.info),
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
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: Icon(icon, color: AppColors.info),
        ),
      ),
    );
  }
}
