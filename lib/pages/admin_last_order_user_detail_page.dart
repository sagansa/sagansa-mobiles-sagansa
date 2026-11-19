import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../models/last_order_user_detail_model.dart';
import '../services/last_order_user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/whatsapp_utils.dart';
import '../widgets/email_action_row.dart';
import '../widgets/glass_app_bar.dart';

/// Detail satu user di daftar "Order Terakhir User": info + chip WhatsApp,
/// tombol "Tandai Sudah Dihubungi" + riwayat, dan summary produk yang pernah
/// diorder (product / quantity / price / total, all-time order direct).
class AdminLastOrderUserDetailPage extends StatefulWidget {
  const AdminLastOrderUserDetailPage({
    super.key,
    required this.userId,
    this.service,
    this.launchUrlImpl,
  });

  final int userId;

  /// Injection untuk widget test; null = pakai service sungguhan.
  final LastOrderUserService? service;

  /// Injection launcher WhatsApp untuk widget test; null = url_launcher.
  final Future<void> Function(Uri url)? launchUrlImpl;

  @override
  State<AdminLastOrderUserDetailPage> createState() =>
      _AdminLastOrderUserDetailPageState();
}

class _AdminLastOrderUserDetailPageState
    extends State<AdminLastOrderUserDetailPage> {
  late final LastOrderUserService _service;
  late final Future<void> Function(Uri url) _launchUrl;

  LastOrderUserDetail? _detail;
  bool _isLoading = true;
  bool _isMarking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LastOrderUserService();
    _launchUrl = widget.launchUrlImpl ??
        (Uri url) => url_launcher.launchUrl(
              url,
              mode: url_launcher.LaunchMode.externalApplication,
            );
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _service.getDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _markFollowedUp() async {
    if (_isMarking) return;
    setState(() => _isMarking = true);
    try {
      await _service.markFollowedUp(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ditandai sudah dihubungi.')),
      );
      await _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Gagal menandai: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
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
        title: Text(_detail?.name ?? 'Detail User'),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null || _detail == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage ?? 'Detail tidak tersedia.',
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapVerticalMD,
              FilledButton(
                onPressed: _fetchDetail,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      children: [
        _buildInfoCard(theme, detail),
        AppSpacing.gapVerticalMD,
        _buildFollowUpCard(theme, detail),
        AppSpacing.gapVerticalMD,
        _buildProductsCard(theme, detail),
      ],
    );
  }

  /// Kartu info user — pola kartu list (judul bold + email + chip WA +
  /// meta baris ber-icon).
  Widget _buildInfoCard(ThemeData theme, LastOrderUserDetail detail) {
    final dateText = detail.lastOrderAt != null
        ? FormatUtils.formatDate(detail.lastOrderAt!)
        : '-';
    return Card(
      elevation: AppElevation.level1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
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
                    detail.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detail.lastOrderAt != null) ...[
                  AppSpacing.gapHorizontalSM,
                  _recencyPill(theme, detail.lastOrderAt!),
                ],
              ],
            ),
            AppSpacing.gapVerticalXS,
            if (detail.email != null)
              EmailActionRow(
                email: detail.email!,
                launchUrlImpl: widget.launchUrlImpl,
              )
            else
              Text(
                'Tanpa email',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            if (detail.phones.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final p in detail.phones) _buildPhoneChip(theme, p),
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
              'Total: ${FormatUtils.formatCurrency(detail.totalNominal)} '
                  '(${detail.totalOrders} order)',
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu follow-up: tombol tandai + riwayat (terbaru di atas).
  Widget _buildFollowUpCard(ThemeData theme, LastOrderUserDetail detail) {
    final cs = theme.colorScheme;
    return Card(
      elevation: AppElevation.level1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follow-up',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.gapVerticalSM,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isMarking ? null : _markFollowedUp,
                icon: _isMarking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle, size: 18),
                label: const Text('Tandai Sudah Dihubungi'),
              ),
            ),
            AppSpacing.gapVerticalSM,
            if (detail.followUps.isEmpty)
              Text(
                'Belum pernah dihubungi.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              )
            else
              Column(
                children: [
                  for (final f in detail.followUps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 13, color: AppColors.success),
                          AppSpacing.gapHorizontalXS,
                          Expanded(
                            child: Text(
                              f.byName,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            f.createdAt != null
                                ? FormatUtils.formatDate(f.createdAt!)
                                : '-',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Kartu summary produk: tabel ringkas Produk | Qty | Harga | Total.
  Widget _buildProductsCard(ThemeData theme, LastOrderUserDetail detail) {
    final productsTotal =
        detail.products.fold<int>(0, (sum, p) => sum + p.total);

    return Card(
      elevation: AppElevation.level1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produk Diorder',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.gapVerticalSM,
            _productHeaderRow(theme),
            const Divider(height: AppSpacing.md),
            for (final p in detail.products) _productRow(theme, p),
            const Divider(height: AppSpacing.md),
            _productTotalRow(theme, productsTotal),
          ],
        ),
      ),
    );
  }

  static const _nameFlex = 3;
  static const _qtyFlex = 1;
  static const _priceFlex = 2;
  static const _totalFlex = 2;

  Widget _productHeaderRow(ThemeData theme) {
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        Expanded(flex: _nameFlex, child: Text('Produk', style: style)),
        Expanded(flex: _qtyFlex, child: Text('Qty', style: style, textAlign: TextAlign.right)),
        Expanded(flex: _priceFlex, child: Text('Harga', style: style, textAlign: TextAlign.right)),
        Expanded(flex: _totalFlex, child: Text('Total', style: style, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _productRow(ThemeData theme, LastOrderProductSummary p) {
    final style = theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: _nameFlex,
            child: Text(
              p.name,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: _qtyFlex,
            child: Text(
              FormatUtils.formatNumber(p.quantity),
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: _priceFlex,
            child: Text(
              FormatUtils.formatCurrency(p.unitPrice),
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: _totalFlex,
            child: Text(
              FormatUtils.formatCurrency(p.total),
              style: style?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTotalRow(ThemeData theme, int total) {
    return Row(
      children: [
        Expanded(
          flex: _nameFlex + _qtyFlex + _priceFlex,
          child: Text(
            'Total Produk',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: _totalFlex,
          child: Text(
            FormatUtils.formatCurrency(total),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Pill jarak waktu sejak order terakhir — sama dengan kartu list:
  /// ≤14 hari hijau, 15–60 oranye, >60 merah.
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
    String label;
    if (days <= 0) {
      label = 'Hari ini';
    } else if (days == 1) {
      label = 'Kemarin';
    } else if (days < 30) {
      label = '$days hari lalu';
    } else if (days < 365) {
      label = '${days ~/ 30} bln lalu';
    } else {
      label = '${days ~/ 365} thn lalu';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w500),
      ),
    );
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
