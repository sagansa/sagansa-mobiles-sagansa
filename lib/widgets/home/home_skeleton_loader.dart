import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../skeleton_loading.dart';

/// Skeleton loader untuk seluruh body Home saat initial load data.
///
/// Menggunakan [SkeletonLoading] adaptif light/dark mode untuk merefleksikan
/// tata letak sebenarnya dari Home (Header, Presence Card, Grid Menu / KPI).
class HomeSkeletonLoader extends StatelessWidget {
  const HomeSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Skeleton Card (compact single-row)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppSpacing.borderRadiusLG,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                SkeletonLoading(
                  width: 38,
                  height: 38,
                  borderRadius: BorderRadius.circular(19),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SkeletonLoading(width: 140, height: 14),
                      SizedBox(height: 5),
                      SkeletonLoading(width: 190, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapVerticalSM,

          // 2. Hero Card Skeleton (Presence or Primary KPI)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppSpacing.borderRadiusLG,
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonLoading(
                        width: 36,
                        height: 36,
                        borderRadius: AppSpacing.borderRadiusSM,
                      ),
                      AppSpacing.gapHorizontalSM,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonLoading(width: 110, height: 14),
                          SizedBox(height: 4),
                          SkeletonLoading(width: 70, height: 10),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  SkeletonLoading(
                    width: double.infinity,
                    height: 52,
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                  AppSpacing.gapVerticalMD,
                  SkeletonLoading(
                    width: double.infinity,
                    height: 44,
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapVerticalMD,

          // 3. Section Title Skeleton
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SkeletonLoading(width: 130, height: 16),
          ),
          AppSpacing.gapVerticalSM,

          // 4. Grid Skeleton (3x2 or 2x3 cards)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.0,
            children: List.generate(
              6,
              (_) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusLG,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: AppSpacing.paddingSM,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SkeletonLoading(
                            width: 22,
                            height: 22,
                            borderRadius: AppSpacing.borderRadiusSM,
                          ),
                        ],
                      ),
                      const SkeletonLoading(width: 44, height: 18),
                      const SkeletonLoading(width: 55, height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
