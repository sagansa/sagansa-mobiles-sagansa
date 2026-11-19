import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/fuel_service_payment_provider.dart';
import '../services/fuel_service_service.dart';
import '../services/image_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/fuel_service_payment_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/list_thumbnail.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/modern_dropdown.dart';
import 'fuel_service_detail_page.dart';
import 'fuel_service_form_page.dart';

class FuelServiceListPage extends StatefulWidget {
  const FuelServiceListPage({super.key});

  @override
  State<FuelServiceListPage> createState() => _FuelServiceListPageState();
}

class _FuelServiceListPageState extends State<FuelServiceListPage> {
  final FuelServiceService _service = FuelServiceService();
  final ScrollController _scrollController = ScrollController();
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;
  List<Map<String, dynamic>> _services = [];
  bool _isAdmin = false;
  bool _paymentMode = false;

  // Filter state (status & fuelService untuk semua role; userFilter admin only).
  // status: 0 = Semua, 1 = Pending, 2 = Lunas
  // fuelService: 0 = Semua, 1 = Fuel, 2 = Service
  // paymentType: 0 = Semua, 2 = Tunai, 1 = Transfer
  // selectedUserId: null = Semua User, atau id user spesifik (admin only)
  int _statusFilter = 0;
  int _fuelServiceFilter = 0;
  int _paymentTypeFilter = 0;
  int? _selectedUserId;
  List<Map<String, dynamic>> _userList = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadAdminRole();
    _fetch();
    _scrollController.addListener(_onScroll);
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

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  Future<void> _loadAdminRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final userData = json.decode(userString);
      final roles = List<String>.from(userData['roles'] ?? []);
      if (mounted) {
        setState(() {
          _isAdmin = roles.any((r) => [
                'admin',
                'super_admin',
                'supervisor',
                'owner',
                'panel_user'
              ].contains(r));
        });
        // Load user list hanya setelah role diketahui (admin only).
        if (_isAdmin) {
          _loadUserList();
        }
      }
    }
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _services = [];
      _hasMore = true;
    });

    try {
      final result = await _service.getFuelServicesPaged(
        allStores: _isAdmin,
        page: _page,
        createdById: _selectedUserId,
        status: _statusFilter == 0 ? null : _statusFilter.toString(),
        fuelService: _fuelServiceFilter == 0 ? null : _fuelServiceFilter.toString(),
        paymentTypeId: _paymentTypeFilter == 0 ? null : _paymentTypeFilter.toString(),
      );
      if (!mounted) return;
      setState(() {
        _services = result['data'] as List<Map<String, dynamic>>;
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
      final result = await _service.getFuelServicesPaged(
        allStores: _isAdmin,
        page: _page + 1,
        createdById: _selectedUserId,
        status: _statusFilter == 0 ? null : _statusFilter.toString(),
        fuelService: _fuelServiceFilter == 0 ? null : _fuelServiceFilter.toString(),
        paymentTypeId: _paymentTypeFilter == 0 ? null : _paymentTypeFilter.toString(),
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _services.addAll(result['data'] as List<Map<String, dynamic>>);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  /// Load list user yang punya fuel service (admin only filter).
  Future<void> _loadUserList() async {
    if (!_isAdmin) return;
    setState(() => _isLoadingUsers = true);
    try {
      final users = await _service.getUsersForFuelServicePayment();
      if (!mounted) return;
      setState(() {
        _userList = users.cast<Map<String, dynamic>>().toList();
        _isLoadingUsers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  /// Chip row + dropdown untuk filter user/status/fuel_service.
  /// Disembunyikan saat _paymentMode aktif (fokus pilih item).
  Widget _buildFilterRow(ThemeData theme, ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListView(
          padding: EdgeInsets.only(top: AppBarInsets.top(context)),
        scrollDirection: Axis.horizontal,
        children: [
          // User filter (admin only — staff tetap lihat milik sendiri).
          if (_isAdmin) ...[
            _buildUserFilterChip(cs),
            AppSpacing.gapHorizontalMD,
            // Separator visual.
            Container(width: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
            AppSpacing.gapHorizontalMD,
          ],
          // Fuel/Service filter.
          _filterChip(
            cs: cs,
            activeIndex: _fuelServiceFilter,
            onTap: (i) {
              setState(() => _fuelServiceFilter = i);
              _fetch();
            },
            options: const ['Semua', 'Fuel', 'Service'],
          ),
          AppSpacing.gapHorizontalMD,
          Container(width: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          AppSpacing.gapHorizontalMD,
          // Status filter.
          _filterChip(
            cs: cs,
            activeIndex: _statusFilter,
            onTap: (i) {
              setState(() => _statusFilter = i);
              _fetch();
            },
            options: const ['Semua', 'Pending', 'Lunas'],
          ),
          AppSpacing.gapHorizontalMD,
          Container(width: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          AppSpacing.gapHorizontalMD,
          // Payment type filter (index 0=Semua, 1=Tunai(2), 2=Transfer(1)).
          _filterChip(
            cs: cs,
            activeIndex: _paymentTypeFilter == 0
                ? 0
                : (_paymentTypeFilter == 2 ? 1 : 2),
            onTap: (i) {
              final value = i == 0 ? 0 : (i == 1 ? 2 : 1);
              setState(() => _paymentTypeFilter = value);
              _fetch();
            },
            options: const ['Semua', 'Tunai', 'Transfer'],
          ),
        ],
      ),
    );
  }

  void _showUserSelectionSheet() {
    final userIds = [null, ..._userList.map((u) => _toInt(u['id'])).whereType<int>()];
    showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DropdownSelectionSheet<int?>(
        title: 'Filter per Pengemudi',
        items: userIds,
        selectedItem: _selectedUserId,
        getLabel: (val) {
          if (val == null) return 'Semua User';
          final u = _userList.firstWhere((e) => _toInt(e['id']) == val, orElse: () => {});
          return u['name']?.toString() ?? 'User #$val';
        },
        getSubtitle: (val) {
          if (val == null) return '';
          final u = _userList.firstWhere((e) => _toInt(e['id']) == val, orElse: () => {});
          return u['email']?.toString() ?? '';
        },
        searchable: _userList.length > 5,
      ),
    ).then((selected) {
      if (selected != _selectedUserId) {
        setState(() => _selectedUserId = selected);
        _fetch();
      }
    });
  }

  /// Chip filter untuk user/pengemudi (admin only).
  Widget _buildUserFilterChip(ColorScheme cs) {
    if (_isLoadingUsers) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text(
              'Memuat user...',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final selectedUser = _userList.firstWhere(
      (u) => _toInt(u['id']) == _selectedUserId,
      orElse: () => {},
    );
    final userLabel = _selectedUserId == null
        ? 'Semua User'
        : (selectedUser['name']?.toString() ?? 'User #$_selectedUserId');

    final isSelected = _selectedUserId != null;

    return GestureDetector(
      onTap: _showUserSelectionSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: AppSpacing.borderRadiusLG,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 14,
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            AppSpacing.gapHorizontalXS,
            Text(
              userLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Generic chip group untuk filter dengan options list.
  Widget _filterChip({
    required ColorScheme cs,
    required int activeIndex,
    required void Function(int) onTap,
    required List<String> options,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(options.length, (i) {
        final selected = activeIndex == i;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
          child: GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: AppSpacing.borderRadiusMD,
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                options[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _openFuelServiceForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FuelServiceFormPage()),
    );
    if (result == true) {
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: Text(_paymentMode ? 'Pilih untuk Bayar Transfer' : 'Bensin & Servis'),
        actions: [
          BarButtonCluster(actions: [
            BarButtonSpec(
              icon: _paymentMode ? Icons.close : Icons.payment,
              tooltip: _paymentMode ? 'Batal' : 'Bayar Transfer',
              onTap: () {
                setState(() => _paymentMode = !_paymentMode);
                if (!_paymentMode) {
                  context.read<FuelServicePaymentProvider>().clearSelection();
                }
              },
            ),
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: 'Tambah Fuel Service',
              onTap: _openFuelServiceForm,
            ),
          ]),
        ],
        bottom: _paymentMode
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: _buildFilterRow(theme, colorScheme),
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _errorMessage != null
                  ? ListView(
                      padding: EdgeInsets.only(
                          top: AppBarInsets.top(context)),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Padding(
                          padding: AppSpacing.paddingLG,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                              AppSpacing.gapVerticalMD,
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge,
                              ),
                              AppSpacing.gapVerticalLG,
                              ElevatedButton(
                                onPressed: _fetch,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _services.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_gas_station_outlined, size: 64, color: colorScheme.outline),
                                AppSpacing.gapVerticalMD,
                                Text('Belum ada riwayat bensin atau servis.', style: textTheme.bodyLarge),
                                AppSpacing.gapVerticalSM,
                                Text(
                                  'Tarik ke bawah untuk menyegarkan',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _services.length + (_hasMore ? 1 : 0),
                          padding: AppSpacing.paddingMD.copyWith(
                              top: AppBarInsets.top(context),
                              bottom: ModernBottomNav.clearance(context)),
                          itemBuilder: (context, index) {
                            if (index == _services.length) {
                              return const Padding(
                                padding: EdgeInsets.all(AppSpacing.md),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final fs = _services[index];
                          final type = fs['fuel_service'] == 1 ? 'Fuel' : 'Service';
                        final isFuel = fs['fuel_service'] == 1;
                        final amount = double.tryParse(fs['amount'].toString()) ?? 0;
                        final date = fs['date'] ?? '';
                        final vehicleNo = fs['vehicle']?['no_register'] ?? 'Kendaraan';
                        final km = fs['km'] ?? 0;
                        final creatorName = fs['created_by']?['name'] ?? 'Staff';
                        final statusStr = fs['status'] == 2 ? 'Lunas / Terhubung' : 'Pending';
                        final isPaid = fs['status'] == 2;
                        final paymentTypeId = fs['payment_type_id'];
                        final canPayTransfer =
                            _paymentMode && !isPaid && paymentTypeId == 1;
                        final imageUrl = ImageService.buildUrl(fs['image']?.toString());

                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FuelServiceDetailPage(service: fs),
                                ),
                              );
                              if (updated == true) {
                                _fetch();
                              }
                            },
                            child: Padding(
                              padding: AppSpacing.paddingMD,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (canPayTransfer)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Checkbox(
                                        value: context
                                            .read<FuelServicePaymentProvider>()
                                            .isSelected(fs['id'] as int),
                                        onChanged: (v) {
                                          final amount =
                                              double.tryParse(fs['amount'].toString()) ?? 0;
                                          final supplier = fs['supplier'];
                                          final error = context
                                              .read<FuelServicePaymentProvider>()
                                              .toggleSelection(
                                                fs['id'] as int,
                                                amount: amount.round(),
                                                // 1 = bensin (reimbursement
                                                // ke rekening pembuat,
                                                // supplier bebas), 2 = servis
                                                // (wajib satu supplier sama).
                                                fuelServiceType: isFuel ? 1 : 2,
                                                supplierId: supplier != null
                                                    ? (supplier['id'] as num?)?.toInt()
                                                    : null,
                                                supplierName: supplier?['name']?.toString(),
                                                bankName: supplier?['bank']?['name']?.toString(),
                                                bankAccountNo: supplier?['bank_account_no']?.toString(),
                                                bankAccountName: supplier?['bank_account_name']?.toString(),
                                                qris: supplier?['qris']?.toString(),
                                              );
                                          if (error != null && mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(error)),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ListThumbnail(
                                    imageUrl: imageUrl,
                                    placeholderIcon: Icons.local_gas_station_outlined,
                                    onTap: imageUrl != null
                                        ? () => _showImageFullscreen(imageUrl)
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                              decoration: BoxDecoration(
                                                color: (isFuel ? AppColors.success : AppColors.warning)
                                                    .withValues(alpha: 0.1),
                                                borderRadius: AppSpacing.borderRadiusSM,
                                              ),
                                              child: Text(
                                                type,
                                                style: textTheme.labelMedium?.copyWith(
                                                  color: isFuel ? AppColors.success : AppColors.warning,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              currencyFormatter.format(amount),
                                              style: textTheme.titleMedium
                                                  ?.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        AppSpacing.gapVerticalSM,
                                        Text(
                                          '$vehicleNo (KM: $km)',
                                          style: textTheme.titleSmall
                                              ?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        AppSpacing.gapVerticalXS,
                                        Text(
                                          'Tanggal: $date | Oleh: $creatorName'
                                          '${fs['supplier']?['name'] != null ? ' | Supplier: ${fs['supplier']['name']}' : ''}',
                                          style: textTheme.bodySmall
                                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                                        ),
                                        AppSpacing.gapVerticalSM,
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              statusStr,
                                              style: textTheme.labelMedium?.copyWith(
                                                color: isPaid ? AppColors.success : colorScheme.error,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (imageUrl != null)
                                              IconButton(
                                                icon: const Icon(Icons.share, size: 18),
                                                onPressed: () => _shareImage(
                                                    imageUrl,
                                                    fs['id']),
                                                tooltip: 'Bagikan',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                          ],
                                        ),
                                        if (fs['notes'] != null) ...[
                                          AppSpacing.gapVerticalXS,
                                          (() {
                                            final stripped = _stripHtmlTags(fs['notes'].toString());
                                            if (stripped.isNotEmpty) {
                                              return Text(
                                                stripped,
                                                style: textTheme.bodySmall
                                                    ?.copyWith(fontStyle: FontStyle.italic),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          })(),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )),
      bottomNavigationBar: _paymentMode &&
              context.watch<FuelServicePaymentProvider>().selectedCount > 0
          ? _buildPaymentActionBar()
          : ModernBottomNav(
              currentIndex: 3,
              onTap: (index) {
                if (index != 3) {
                  Navigator.pop(context);
                }
              },
            ),
    );
  }

  void _showImageFullscreen(String url) {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: GlassAppBar(
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.87),
            foregroundColor: colorScheme.surface,
            title: Text('Bukti Bensin & Servis',
                style: TextStyle(color: colorScheme.surface)),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: colorScheme.surface.withValues(alpha: 0.54),
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareImage(String url, dynamic id) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('download failed');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fuel_service_$id.jpg');
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Bukti Bensin & Servis'),
      );
    } catch (_) {
      if (mounted) {
        await SharePlus.instance.share(ShareParams(text: url));
      }
    }
  }

  Widget _buildPaymentActionBar() {
    final provider = context.read<FuelServicePaymentProvider>();
    return GlassContainer.bottomBar(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${provider.selectedCount} item terpilih',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    FormatUtils.formatCurrency(provider.totalAmount),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await FuelServicePaymentBottomSheet.show(context);
                if (success == true) {
                  setState(() => _paymentMode = false);
                  _fetch();
                }
              },
              icon: const Icon(Icons.payment),
              label: const Text('Bayar'),
              style: AppButtonStyle.elevated(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.gold,
              ),
            ),
          ],
        ),
    );
  }
}



String _stripHtmlTags(String htmlText) {
  final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
  return htmlText.replaceAll(exp, '').trim();
}
