import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../models/utility_usage_model.dart';
import '../services/presence_service.dart';
import '../services/utility_usage_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/status_badge.dart';
import 'utility_usage_form_page.dart';

class UtilityUsageDetailPage extends StatefulWidget {
  final int usageId;

  const UtilityUsageDetailPage({super.key, required this.usageId});

  @override
  State<UtilityUsageDetailPage> createState() => _UtilityUsageDetailPageState();
}

class _UtilityUsageDetailPageState extends State<UtilityUsageDetailPage>
    with SingleTickerProviderStateMixin {
  final UtilityUsageService _service = UtilityUsageService();
  UtilityUsageModel? _item;
  bool _isLoading = true;
  bool _isClockedIn = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _checkClockIn();
    _fetch();
  }

  Future<void> _checkClockIn() async {
    final clockedIn = await PresenceService().isClockedIn();
    if (!mounted) return;
    setState(() => _isClockedIn = clockedIn);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _service.getUtilityUsage(widget.usageId);
      if (!mounted) return;
      setState(() {
        _item = data;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Pemakaian?',
      content:
          'Data pemakaian utility "${_item?.utilityDisplayName}" akan dihapus permanen.',
      confirmText: 'Hapus',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await _service.deleteUtilityUsage(widget.usageId);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Pemakaian utility berhasil dihapus.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _openEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UtilityUsageFormPage(usage: _item)),
    );
    if (result == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: _item != null ? Text(_item!.utilityDisplayName) : const Text('Detail Pemakaian'),
        actions: _item != null
            ? [
                BarButtonCluster(actions: [
                  if (_isClockedIn)
                    BarButtonSpec(
                      icon: Icons.edit_rounded,
                      tooltip: 'Edit',
                      onTap: _openEdit,
                    ),
                  BarButtonSpec(
                    icon: Icons.delete_outline,
                    tooltip: 'Hapus',
                    onTap: _delete,
                  ),
                ]),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _buildContent(colorScheme, theme),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, ThemeData theme) {
    final item = _item!;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 16,
            ModernBottomNav.clearance(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(
                  label: item.statusText,
                  type: _statusType(item.status),
                  size: BadgeSize.medium,
                ),
              ],
            ),
            AppSpacing.gapVerticalLG,
            _buildSectionTitle('Detail Pemakaian', theme),
            _buildInfoCard(
              colorScheme: colorScheme,
              theme: theme,
              children: [
                _buildDetailRow(
                  icon: Icons.electrical_services_rounded,
                  label: 'Utility',
                  value: item.utilityDisplayName,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                if (item.utilityNumber != null)
                  _buildDetailRow(
                    icon: Icons.numbers_rounded,
                    label: 'Nomor Utility',
                    value: item.utilityNumber!,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                _buildDetailRow(
                  icon: Icons.speed_rounded,
                  label: 'Hasil',
                  value: '${item.formattedResult} ${item.unitName ?? ''}',
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => _copyToClipboard(item.result),
                ),
                _buildDetailRow(
                  icon: Icons.straighten_rounded,
                  label: 'Satuan',
                  value: item.unitName ?? '-',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                _buildDetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Catatan',
                  value: item.cleanNotes.isEmpty ? '-' : item.cleanNotes,
                  colorScheme: colorScheme,
                  theme: theme,
                  isLast: true,
                ),
              ],
            ),
            AppSpacing.gapVerticalMD,
            _buildSectionTitle('Informasi', theme),
            _buildInfoCard(
              colorScheme: colorScheme,
              theme: theme,
              children: [
                if (item.createdByName != null)
                  _buildDetailRow(
                    icon: Icons.person_pin_rounded,
                    label: 'Dibuat oleh',
                    value: item.createdByName!,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                if (item.approvedByName != null)
                  _buildDetailRow(
                    icon: Icons.verified_rounded,
                    label: 'Disetujui oleh',
                    value: item.approvedByName!,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                if (item.createdAt != null)
                  _buildDetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Tanggal',
                    value: _formatDate(item.createdAt!),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                _buildDetailRow(
                  icon: Icons.tag_rounded,
                  label: 'ID',
                  value: '#${item.id}',
                  colorScheme: colorScheme,
                  theme: theme,
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  StatusType _statusType(int status) {
    switch (status) {
      case 2:
        return StatusType.success;
      case 3:
        return StatusType.neutral;
      case 4:
        return StatusType.error;
      default:
        return StatusType.warning;
    }
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required ColorScheme colorScheme,
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
    required ThemeData theme,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: AppColors.info),
                const SizedBox(width: AppSpacing.sectionGap),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapVerticalXS,
                      Text(
                        value,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.copy_rounded, size: 14, color: AppColors.info),
                ],
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 0,
              indent: 46,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            AppSpacing.gapVerticalMD,
            Text(_errorMessage!),
            AppSpacing.gapVerticalMD,
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showInfoSnackBar(context, '"$text" disalin ke clipboard.');
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
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
        'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
