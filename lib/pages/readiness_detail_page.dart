import 'package:flutter/material.dart';

import '../models/readiness_model.dart';
import '../services/readiness_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/status_badge.dart';

/// Detail kesiapan diri dengan navigasi geser (kiri/kanan) antar data.
/// Admin/super_admin dapat mengubah status pemeriksaan.
class ReadinessDetailPage extends StatefulWidget {
  final List<ReadinessModel> items;
  final int initialIndex;
  final bool isAdmin;

  const ReadinessDetailPage({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.isAdmin,
  });

  @override
  State<ReadinessDetailPage> createState() => _ReadinessDetailPageState();
}

class _ReadinessDetailPageState extends State<ReadinessDetailPage> {
  final ReadinessService _service = ReadinessService();
  late final PageController _pageController;
  late final List<ReadinessModel> _items;
  late int _index;
  bool _hasChanged = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  StatusType _statusType(int? s) =>
      s == 2 ? StatusType.success : StatusType.warning;

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _changeStatus(int newStatus) async {
    final item = _items[_index];
    if (item.status == newStatus || _isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await _service.updateStatus(item.id, newStatus);
      if (!mounted) return;
      setState(() {
        _items[_index] = item.copyWith(status: newStatus);
        _isUpdating = false;
        _hasChanged = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
        appBar: GlassAppBar(
          title: const Text('Detail Kesiapan Diri'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '${_index + 1}/${_items.length}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: _items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (ctx, i) => _buildPage(_items[i], cs, tt),
        ),
      ),
    );
  }

  Widget _buildPage(ReadinessModel item, ColorScheme cs, TextTheme tt) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.createdByName ?? 'Tanpa nama',
                    style: tt.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: item.statusLabel,
                  type: _statusType(item.status),
                  size: BadgeSize.medium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.info),
                const SizedBox(width: AppSpacing.xs),
                Text(_formatDate(item.createdAt), style: tt.bodyMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _bigImage('Selfie', item.selfieUrl, Icons.face, cs, height: 300),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _bigImage(
                        'Tangan Kiri', item.leftHandUrl, Icons.back_hand, cs,
                        height: 150)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _bigImage(
                        'Tangan Kanan', item.rightHandUrl, Icons.front_hand, cs,
                        height: 150)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.isAdmin) _buildStatusControl(item, tt, cs),
          ],
        ),
      ),
    );
  }

  Widget _bigImage(
      String label, String? url, IconData icon, ColorScheme cs,
      {required double height}) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: tt.labelMedium
                ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xs),
        url == null
            ? ClipRRect(
                borderRadius: AppSpacing.borderRadiusMD,
                child: Container(
                  height: height,
                  width: double.infinity,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Center(
                      child: Icon(icon, size: 40, color: AppColors.info)),
                ),
              )
            : DetailImageView(
                imageUrl: url,
                height: height,
                previewTitle: label,
              ),
      ],
    );
  }

  Widget _buildStatusControl(ReadinessModel item, TextTheme tt, ColorScheme cs) {
    final current = item.status ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubah Status Pemeriksaan',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 1,
                  label: Text('Belum Diperiksa'),
                  icon: Icon(Icons.pending_actions)),
              ButtonSegment(
                  value: 2,
                  label: Text('Sudah Diperiksa'),
                  icon: Icon(Icons.check_circle_outline)),
            ],
            selected: {current},
            showSelectedIcon: false,
            emptySelectionAllowed: false,
            multiSelectionEnabled: false,
            onSelectionChanged: _isUpdating
                ? null
                : (selection) {
                    final v = selection.isEmpty ? null : selection.first;
                    if (v != null) _changeStatus(v);
                  },
          ),
        ),
        if (_isUpdating)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
    );
  }
}
