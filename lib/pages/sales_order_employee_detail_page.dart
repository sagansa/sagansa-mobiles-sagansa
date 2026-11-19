import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sales_order_employee_model.dart';
import '../services/sales_order_employee_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/detail/detail_product_tile.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';
import 'sales_order_employee_form_page.dart';

/// Detail penjualan employee.
///
/// - Role admin/super_admin: tombol "Ubah Status" (bottom sheet 1..4), tombol "Hapus".
/// - Role sales pemilik (canEdit=true & !isLocked): tombol "Edit" & "Hapus".
class SalesOrderEmployeeDetailPage extends StatefulWidget {
  final int orderId;
  final bool canEdit; // true untuk sales; admin tidak create/edit via mobile

  const SalesOrderEmployeeDetailPage({
    super.key,
    required this.orderId,
    required this.canEdit,
  });

  @override
  State<SalesOrderEmployeeDetailPage> createState() =>
      _SalesOrderEmployeeDetailPageState();
}

class _SalesOrderEmployeeDetailPageState
    extends State<SalesOrderEmployeeDetailPage> {
  final SalesOrderEmployeeService _service = SalesOrderEmployeeService();
  SalesOrderEmployeeModel? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// True jika ada mutasi yang mempengaruhi list (status / edit / hapus).
  /// Dikirim balik ke list page lewat Navigator.pop(true) agar list di-refresh.
  bool _dirty = false;

  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadOrder();
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
        });
      }
    }
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await _service.getDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = o;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Sales hanya boleh edit/hapus jika pemilik & belum valid. Admin selalu boleh hapus.
  bool get _canEdit => widget.canEdit && _order != null && !_order!.isLocked;
  bool get _canDelete => _isAdmin || _canEdit;

  Future<void> _openEdit() async {
    if (_order == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => SalesOrderEmployeeFormPage(order: _order)),
    );
    if (result == true) {
      _dirty = true;
      _loadOrder();
    }
  }

  Future<void> _confirmDelete() async {
    if (_order == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Penjualan?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: AppButtonStyle.filled(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _service.delete(_order!.id);
      if (!mounted) return;
      SnackbarUtils.success(context, 'Penjualan dihapus.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(
          context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openStatusSheet() async {
    if (_order == null) return;
    // Status terkunci setelah Valid: pembayaran sudah final (isLocked), tidak
    // ada perubahan status yang ditawarkan lagi.
    if (_order!.isLocked) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Ubah Status Pembayaran',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              // Label harus sinkron dengan backend: 1 = Belum Diperiksa,
              // 2 = Valid, 3 = Tidak Valid, 4 = Menunggu Pembayaran.
              _statusTile(ctx, 1, 'Belum Diperiksa'),
              _statusTile(ctx, 2, 'Valid'),
              _statusTile(ctx, 3, 'Tidak Valid'),
              _statusTile(ctx, 4, 'Menunggu Pembayaran'),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == _order!.paymentStatus) return;

    setState(() => _busy = true);
    try {
      final updated = await _service.updatePaymentStatus(_order!.id, selected);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _dirty = true;
      });
      SnackbarUtils.success(context, 'Status pembayaran diperbarui.');
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(
          context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _statusTile(BuildContext ctx, int value, String label) {
    final isSelected = _order?.paymentStatus == value;
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.success) : null,
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _dirty);
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
        appBar: GlassAppBar(title: const Text('Detail Penjualan')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBody(message: _error!, onRetry: _loadOrder)
                : _order == null
                    ? const Center(child: Text('Data tidak ditemukan.'))
                    : RefreshIndicator(
                        onRefresh: _loadOrder,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppBarInsets.top(context),
                            AppSpacing.md,
                            AppSpacing.md + context.systemBottomInset,
                          ),
                          children: [
                            _buildInfoSection(context),
                            const SizedBox(height: 10),
                            _buildItemsSection(context),
                            if (_order!.imagePaymentUrl != null) ...[
                              const SizedBox(height: 10),
                              _buildImageSection(context),
                            ],
                            const SizedBox(height: 14),
                            _buildActions(context),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final o = _order!;
    final color = _statusColor(cs);

    return DetailSectionCard(
      title: 'Informasi Penjualan',
      icon: Icons.receipt_long_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppSpacing.borderRadiusSM,
        ),
        child: Text(
          o.paymentStatusLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      itemSpacing: 6,
      children: [
        DetailRow(
          label: 'Konsumen',
          value: o.deliveryAddressName ?? '-',
          valueBold: true,
        ),
        DetailRow(
          label: 'Toko',
          value: o.storeName ?? '-',
        ),
        DetailRow(
          label: 'Tanggal',
          value: o.deliveryDate != null
              ? FormatUtils.formatDate(o.deliveryDate!)
              : '-',
        ),
        DetailRow(
          label: 'Rekening Tujuan',
          value: o.transferToAccountName ?? '-',
        ),
        if (o.orderedByName != null)
          DetailRow(
            label: 'Sales',
            value: o.orderedByName!,
          ),
        if (o.notes != null && o.notes!.isNotEmpty)
          DetailRow(
            label: 'Catatan',
            value: o.notes!,
          ),
      ],
    );
  }

  Widget _buildItemsSection(BuildContext context) {
    final o = _order!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DetailSectionCard(
      title: 'Item Penjualan (${o.items.length})',
      icon: Icons.inventory_2_outlined,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      children: [
        ...o.items.map((i) => DetailProductTile(
              productName: i.productName,
              productUnit: i.productUnit,
              quantity: i.quantity,
              formattedUnitPrice: FormatUtils.formatCurrency(i.unitPrice),
              formattedSubtotalPrice: FormatUtils.formatCurrency(i.subtotalPrice),
            )),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Nilai Penjualan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                FormatUtils.formatCurrency(o.totalPrice),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final o = _order!;
    if (o.imagePaymentUrl == null) return const SizedBox.shrink();

    return DetailSectionCard(
      title: 'Bukti Pembayaran',
      icon: Icons.payments_outlined,
      child: DetailImageView(
        imageUrl: o.imagePaymentUrl!,
        aspectRatio: 16 / 9,
        previewTitle: 'Bukti Pembayaran',
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final children = <Widget>[];
    // Setelah Valid (isLocked) status pembayaran final — tombol ubah status
    // tidak ditawarkan lagi; admin tetap bisa hapus.
    if (_isAdmin && _order != null && !_order!.isLocked) {
      children.add(
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _openStatusSheet,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Ubah Status Pembayaran'),
          style: AppButtonStyle.filled(
            minimumSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }
    if (_canEdit) {
      if (children.isNotEmpty) children.add(AppSpacing.gapVerticalSM);
      children.add(
        FilledButton.icon(
          onPressed: _busy ? null : _openEdit,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit Penjualan'),
          style: AppButtonStyle.filled(
            minimumSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }
    if (_canDelete) {
      if (children.isNotEmpty) children.add(AppSpacing.gapVerticalSM);
      children.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : _confirmDelete,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
          label: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          style: AppButtonStyle.outlined(
            foregroundColor: AppColors.primary,
            borderColor: AppColors.error,
            minimumSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(children: children);
  }

  Color _statusColor(ColorScheme cs) {
    switch (_order!.paymentStatus) {
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
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            AppSpacing.gapVerticalSM,
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
