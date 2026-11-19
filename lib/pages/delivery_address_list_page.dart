import 'package:flutter/material.dart';

import '../models/delivery_address_model.dart';
import '../services/delivery_address_service.dart';
import '../theme/app_spacing.dart';
import '../utils/error_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import 'delivery_address_form_page.dart';

/// Daftar calon konsumen (DeliveryAddress) milik user sales.
///
/// Tap item → edit. FAB "+" → tambah baru. Tanpa fitur hapus.
/// Di-embed di [SalesHomePage] dengan `showAppBar: false`.
class DeliveryAddressListPage extends StatefulWidget {
  /// Set false saat di-embed di [SalesHomePage] agar tidak muncul AppBar
  /// ganda (halaman induk sudah punya AppBar + tab bar).
  final bool showAppBar;

  const DeliveryAddressListPage({super.key, this.showAppBar = true});

  @override
  State<DeliveryAddressListPage> createState() =>
      DeliveryAddressListPageState();
}

/// Public supaya induk ([SalesHomePage]) bisa memanggil [openCreate]
/// via `GlobalKey<DeliveryAddressListPageState>` — pola yang sama dengan
/// [SalesOrderEmployeeListPageState].
class DeliveryAddressListPageState extends State<DeliveryAddressListPage> {
  final DeliveryAddressService _service = DeliveryAddressService();

  List<DeliveryAddressModel> _items = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _service.getList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.sanitize(e);
        _isLoading = false;
      });
    }
  }

  /// Buka form create, lalu refresh list jika ada konsumen baru.
  /// Public supaya bisa dipanggil dari AppBar induk saat halaman ini
  /// di-embed dengan `showAppBar: false`.
  Future<void> openCreate() async {
    final created = await Navigator.push<DeliveryAddressModel>(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryAddressFormPage()),
    );
    if (created != null) _loadData();
  }

  Future<void> _openEdit(DeliveryAddressModel address) async {
    final updated = await Navigator.push<DeliveryAddressModel>(
      context,
      MaterialPageRoute(
          builder: (_) => DeliveryAddressFormPage(address: address)),
    );
    if (updated != null) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: widget.showAppBar
          ? GlassAppBar(
              title: const Text('Konsumen'),
              actions: [
                BarButtonCluster(
                  actions: [
                    BarButtonSpec(
                      icon: Icons.add_rounded,
                      iconSize: 22,
                      tooltip: 'Tambah Konsumen',
                      onTap: _isLoading ? null : openCreate,
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: _buildBody(theme, colorScheme),
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
                onPressed: _loadData,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt_outlined,
                  size: 48, color: colorScheme.onSurfaceVariant),
              AppSpacing.gapVerticalSM,
              Text(
                'Belum ada konsumen. Tap + untuk menambahkan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.paddingHorizontalMD.copyWith(
          top: AppBarInsets.top(context),
        ),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final a = _items[index];
          return _CustomerTile(
            address: a,
            onTap: () => _openEdit(a),
          );
        },
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final DeliveryAddressModel address;
  final VoidCallback onTap;
  const _CustomerTile({
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: Icon(Icons.person_outline,
                    color: cs.primary, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.displayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (address.recipientName.isNotEmpty &&
                        address.recipientName != address.name)
                      Text(
                        address.recipientName,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (address.recipientTelpNo.isNotEmpty)
                      Text(
                        address.recipientTelpNo,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (address.address.isNotEmpty)
                      Text(
                        address.address,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (address.subdistrictName != null ||
                        address.cityName != null)
                      Text(
                        [
                          address.subdistrictName,
                          address.districtName,
                          address.cityName,
                          address.provinceName,
                        ]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(', '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}