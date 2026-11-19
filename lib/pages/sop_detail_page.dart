import 'package:flutter/material.dart';

import '../models/sop_model.dart';
import '../services/sop_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

/// Detail SOP: ringkasan + reader langkah-demi-langkah bergambar.
///
/// SOP dengan ≥2 langkah dibaca mode pager (geser antar halaman:
/// pendahuluan → langkah 1..N) dengan indikator progres; sisanya
/// ditampilkan sebagai halaman gulir biasa.
class SopDetailPage extends StatefulWidget {
  final int sopId;

  const SopDetailPage({super.key, required this.sopId});

  @override
  State<SopDetailPage> createState() => _SopDetailPageState();
}

class _SopDetailPageState extends State<SopDetailPage> {
  final SopService _service = SopService();
  final PageController _pageController = PageController();

  SopModel? _sop;
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final sop = await _service.getSopDetail(widget.sopId);
      if (!mounted) return;
      setState(() {
        _sop = sop;
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

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Panduan SOP',
      body: SafeArea(
        top: true,
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: _errorMessage!,
                    subtitle: 'Terjadi kesalahan saat memuat SOP',
                    action: ElevatedButton.icon(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  )
                : _sop == null
                    ? const SizedBox.shrink()
                    : _buildContent(context, _sop!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SopModel sop) {
    if (sop.steps.length >= 2) {
      return Column(
        children: [
          _buildCompactHeader(context, sop),
          Expanded(child: _buildPager(context, sop)),
        ],
      );
    }
    return _buildScrollMode(context, sop);
  }

  /// Header ringkas yang selalu terlihat di mode pager.
  Widget _buildCompactHeader(BuildContext context, SopModel sop) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + AppSpacing.xs, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sop.categoryName != null)
            StatusBadge(label: sop.categoryName!, type: StatusType.info),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sop.title,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPager(BuildContext context, SopModel sop) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalPages = sop.steps.length + 1; // + halaman pendahuluan.
    final isIntro = _currentPage == 0;
    final stepNumber = _currentPage; // Halaman n = langkah n-1... halaman 1 = langkah 1.

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isIntro
                        ? 'Pendahuluan'
                        : 'Langkah $stepNumber dari ${sop.steps.length}',
                    style: textTheme.labelMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '$_currentPage/${totalPages - 1} halaman',
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (_currentPage + 1) / totalPages,
                minHeight: 4,
                borderRadius: AppSpacing.borderRadiusFull,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              if (index == 0) return _buildIntroPage(context, sop);
              final step = sop.steps[index - 1];
              final isLast = index == totalPages - 1;
              return _buildStepPage(context, step, index, isLast);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIntroPage(BuildContext context, SopModel sop) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sop.coverImageUrl != null) ...[
            DetailImageView(
              imageUrl: sop.coverImageUrl!,
              height: 220,
              previewTitle: sop.title,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (sop.description != null && sop.description!.isNotEmpty)
            Text(sop.description!, style: textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(Icons.swipe_left_rounded,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Geser ke kiri untuk mulai membaca ${sop.steps.length} langkah panduan.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPage(
      BuildContext context, SopStepModel step, int pageNumber, bool isLast) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$pageNumber',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  step.title,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (step.description != null && step.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(step.description!, style: textTheme.bodyLarge),
          ],
          if (step.imageUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            DetailImageView(
              imageUrl: step.imageUrl!,
              height: 240,
              previewTitle: 'Langkah $pageNumber — ${step.title}',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (isLast)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Selesai Membaca'),
              ),
            ),
          if (!isLast)
            Center(
              child: Text(
                'Geser untuk lanjut ke langkah berikutnya',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  /// Mode gulir untuk SOP tanpa langkah atau berlangkah tunggal.
  Widget _buildScrollMode(BuildContext context, SopModel sop) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sop.categoryName != null) ...[
            StatusBadge(label: sop.categoryName!, type: StatusType.info),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            sop.title,
            style:
                textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          if (sop.coverImageUrl != null) ...[
            DetailImageView(
              imageUrl: sop.coverImageUrl!,
              height: 220,
              previewTitle: sop.title,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (sop.description != null && sop.description!.isNotEmpty)
            Text(sop.description!, style: textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          if (sop.steps.isEmpty)
            const EmptyState(
              icon: Icons.format_list_numbered_outlined,
              title: 'SOP ini belum memiliki langkah panduan.',
            )
          else
            _buildInlineStep(context, sop.steps.first, 1),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildInlineStep(
      BuildContext context, SopStepModel step, int number) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                step.title,
                style:
                    textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        if (step.description != null && step.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(step.description!, style: textTheme.bodyMedium),
        ],
        if (step.imageUrl != null) ...[
          const SizedBox(height: AppSpacing.md),
          DetailImageView(
            imageUrl: step.imageUrl!,
            height: 240,
            previewTitle: 'Langkah $number — ${step.title}',
          ),
        ],
      ],
    );
  }
}
