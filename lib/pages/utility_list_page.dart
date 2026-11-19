import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/utility_model.dart';
import '../services/utility_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'utility_form_page.dart';

class UtilityListPage extends StatefulWidget {
  const UtilityListPage({super.key});

  @override
  State<UtilityListPage> createState() => _UtilityListPageState();
}

class _UtilityListPageState extends State<UtilityListPage> {
  final UtilityService _service = UtilityService();

  List<UtilityModel> _items = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Filters
  int? _selectedStoreId;
  int? _selectedCategory;
  List<Map<String, dynamic>> _stores = [];

  // Admin (create/edit/ubah status); role lain hanya lihat aktif.
  bool _isAdmin = false;

  List<Map<String, dynamic>> get _filteredCategories => const [
        {'id': 1, 'label': 'Listrik'},
        {'id': 2, 'label': 'Air'},
        {'id': 3, 'label': 'Internet'},
      ];

  bool get _hasActiveFilters =>
      _selectedStoreId != null || _selectedCategory != null;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStoreId != null) count++;
    if (_selectedCategory != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadStores();
    _loadRoleAndFetch();
  }

  Future<void> _loadRoleAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final roles = List<String>.from(json.decode(userString)['roles'] ?? []);
      _isAdmin = roles.contains('admin') || roles.contains('super_admin');
    }
    if (!mounted) return;
    _fetch();
  }

  Future<void> _loadStores() async {
    try {
      final stores = await _service.getStores();
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await _service.getUtilities(
        storeId: _selectedStoreId,
        includeInactive: _isAdmin,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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

  List<UtilityModel> get _filteredItems {
    if (_selectedCategory == null) return _items;
    return _items.where((u) => u.category == _selectedCategory).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedStoreId = null;
      _selectedCategory = null;
    });
    _fetch();
  }

  void _openFilterSheet() {
    FilterBottomSheet.show(
      context,
      title: 'Filter Utility',
      fields: [
        DropdownFilterField<int>(
          label: 'Toko',
          value: _selectedStoreId,
          options: _stores
              .map((s) => (
                    s['id'] is int
                        ? s['id'] as int
                        : int.parse(s['id'].toString()),
                    s['nickname']?.toString() ?? 'Toko #${s['id']}',
                  ))
              .toList(),
        ),
        DropdownFilterField<int>(
          label: 'Jenis Utility',
          value: _selectedCategory,
          options: _filteredCategories
              .map((c) => (c['id'] as int, c['label'] as String))
              .toList(),
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedStoreId = values['Toko'] as int?;
          _selectedCategory = values['Jenis Utility'] as int?;
        });
        _fetch();
      },
      onReset: () {
        _clearFilters();
      },
    );
  }

  void _copyNumber(String? number) {
    if (number == null || number.isEmpty) return;
    Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nomor "$number" disalin ke clipboard.')),
    );
  }

  StatusType _statusType(int? status) {
    return status == 1 ? StatusType.success : StatusType.neutral;
  }

  Future<void> _openForm({UtilityModel? utility}) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UtilityFormPage(utility: utility)),
    );
    if (changed == true) _fetch();
  }

  Future<void> _toggleStatus(UtilityModel item) async {
    final newStatus = item.status == 1 ? 2 : 1;
    try {
      await _service.updateUtilityStatus(item.id, newStatus);
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((u) => u.id == item.id);
        if (idx >= 0) _items[idx] = item.copyWith(status: newStatus);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPageScaffold(
      titleText: 'Utility',
      actions: [
        BarButtonCluster(actions: [
          if (_hasActiveFilters)
            BarButtonSpec(
              icon: Icons.filter_list_off,
              tooltip: 'Hapus Filter',
              onTap: _clearFilters,
            ),
          BarButtonSpec(
            icon: Icons.tune,
            tooltip: 'Filter',
            badgeCount: _activeFilterCount,
            onTap: _openFilterSheet,
          ),
          if (_isAdmin)
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: 'Tambah Utility',
              onTap: () => _openForm(),
            ),
        ]),
      ],
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 4, // Ops tab
        onTap: (index) {},
      ),
      isLoading: _isLoading || !_hasLoaded,
      errorMessage: _errorMessage,
      onRetry: _fetch,
      isEmpty: _filteredItems.isEmpty,
      emptyState: _buildEmpty(),
      bodyPadding: EdgeInsets.zero,
      body: _buildList(colorScheme, textTheme),
    );
  }

  IconData _categoryIcon(int? category) {
    switch (category) {
      case 1:
        return Icons.bolt_rounded;
      case 2:
        return Icons.water_drop_rounded;
      case 3:
        return Icons.wifi_rounded;
      default:
        return Icons.electrical_services_rounded;
    }
  }

  Color _categoryColor(int? category) {
    switch (category) {
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF0EA5E9);
      case 3:
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.info;
    }
  }

  Widget _buildList(ColorScheme colorScheme, TextTheme textTheme) {
    final items = _filteredItems;
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: AppSpacing.paddingMD.copyWith(
          top: AppBarInsets.top(context) + 8,
          bottom: ModernBottomNav.clearance(context) + 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, idx) => _buildCard(
          items[idx],
          colorScheme,
          textTheme,
        ),
      ),
    );
  }

  Widget _buildCard(
      UtilityModel item, ColorScheme colorScheme, TextTheme textTheme) {
    final statusType = _statusType(item.status);
    final catColor = _categoryColor(item.category);
    final catIcon = _categoryIcon(item.category);

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
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Icon Avatar + Name & Number + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                  child: Icon(catIcon, color: catColor, size: 24),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => _copyNumber(item.number),
                        borderRadius: AppSpacing.borderRadiusSM,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.number ?? '-',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapHorizontalSM,
                StatusBadge(
                  label: item.statusText,
                  type: statusType,
                  size: BadgeSize.small,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Metadata Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.storeNickname != null)
                  _MetaChip(
                    icon: Icons.storefront_rounded,
                    label: item.storeNickname!,
                  ),
                if (item.utilityProviderName != null)
                  _MetaChip(
                    icon: Icons.cable_rounded,
                    label: item.utilityProviderName!,
                  ),
                if (item.unit != null)
                  _MetaChip(
                    icon: Icons.straighten_rounded,
                    label: item.unit!,
                  ),
                _MetaChip(
                  icon: catIcon,
                  label: item.categoryLabel,
                  color: catColor.withValues(alpha: 0.1),
                  textColor: catColor,
                ),
                if (item.prePost != null)
                  _MetaChip(
                    label: item.prePostLabel,
                    color: AppColors.info.withValues(alpha: 0.1),
                    textColor: AppColors.info,
                  ),
              ],
            ),

            // Admin Action Buttons
            if (_isAdmin) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openForm(utility: item),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusMD,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _toggleStatus(item),
                    icon: Icon(
                      item.status == 1
                          ? Icons.toggle_off_outlined
                          : Icons.toggle_on_outlined,
                      size: 16,
                    ),
                    label: Text(
                        item.status == 1 ? 'Nonaktifkan' : 'Aktifkan'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusMD,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppBarInsets.top(context) + 8,
        AppSpacing.md,
        ModernBottomNav.clearance(context) + 16,
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.electrical_services_rounded,
                size: 54,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.5),
              ),
              AppSpacing.gapVerticalMD,
              Text(
                'Belum ada data utility.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  final Color? textColor;

  const _MetaChip({
    this.icon,
    required this.label,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fg = textColor ?? colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ??
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
