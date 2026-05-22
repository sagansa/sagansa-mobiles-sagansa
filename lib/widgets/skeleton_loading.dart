import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Skeleton loading widget for better UX during data loading
class SkeletonLoading extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoading({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        widget.baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppSpacing.borderRadiusXS,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loading for text lines
class SkeletonText extends StatelessWidget {
  final double? width;
  final double height;
  final int lines;
  final double spacing;

  const SkeletonText({
    super.key,
    this.width,
    this.height = 16,
    this.lines = 1,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final isLastLine = index == lines - 1;
        final lineWidth =
            isLastLine && lines > 1 ? (width ?? double.infinity) * 0.7 : width;

        return Padding(
          padding: EdgeInsets.only(bottom: isLastLine ? 0 : spacing),
          child: SkeletonLoading(
            width: lineWidth,
            height: height,
            borderRadius: AppSpacing.borderRadiusXS,
          ),
        );
      }),
    );
  }
}

/// Skeleton loading for circular avatars
class SkeletonAvatar extends StatelessWidget {
  final double size;

  const SkeletonAvatar({
    super.key,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoading(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }
}

/// Skeleton loading for cards
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const SkeletonCard({
    super.key,
    this.width,
    this.height = 120,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin ?? AppSpacing.paddingMD,
      padding: padding ?? AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppSpacing.borderRadiusMD,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonText(height: 20, width: 150),
          AppSpacing.gapVerticalSM,
          const SkeletonText(height: 14, lines: 2),
          const Spacer(),
          Row(
            children: [
              const SkeletonAvatar(size: 24),
              AppSpacing.gapHorizontalSM,
              const SkeletonText(height: 12, width: 80),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading for list items
class SkeletonListItem extends StatelessWidget {
  final bool hasAvatar;
  final bool hasTrailing;
  final EdgeInsetsGeometry? padding;

  const SkeletonListItem({
    super.key,
    this.hasAvatar = true,
    this.hasTrailing = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? AppSpacing.paddingMD,
      child: Row(
        children: [
          if (hasAvatar) ...[
            const SkeletonAvatar(),
            AppSpacing.gapHorizontalMD,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonText(height: 16, width: 120),
                AppSpacing.gapVerticalXS,
                const SkeletonText(height: 12, width: 200),
              ],
            ),
          ),
          if (hasTrailing) ...[
            AppSpacing.gapHorizontalMD,
            const SkeletonLoading(width: 24, height: 24),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loading for grid items
class SkeletonGridItem extends StatelessWidget {
  final double aspectRatio;

  const SkeletonGridItem({
    super.key,
    this.aspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        margin: AppSpacing.paddingXS,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppSpacing.borderRadiusMD,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SkeletonLoading(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
              ),
              AppSpacing.gapVerticalSM,
              const SkeletonText(height: 14, width: 80),
              AppSpacing.gapVerticalXS,
              const SkeletonText(height: 12, width: 60),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading for app bar
class SkeletonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool hasBackButton;
  final bool hasActions;

  const SkeletonAppBar({
    super.key,
    this.hasBackButton = false,
    this.hasActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      leading: hasBackButton
          ? const Padding(
              padding: AppSpacing.paddingMD,
              child: SkeletonLoading(width: 24, height: 24),
            )
          : null,
      title: const SkeletonText(height: 20, width: 120),
      actions: hasActions
          ? [
              const Padding(
                padding: AppSpacing.paddingMD,
                child: SkeletonLoading(width: 24, height: 24),
              ),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Skeleton loading for bottom navigation
class SkeletonBottomNav extends StatelessWidget {
  final int itemCount;

  const SkeletonBottomNav({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(itemCount, (index) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SkeletonLoading(width: 24, height: 24),
              AppSpacing.gapVerticalXS,
              const SkeletonText(height: 10, width: 40),
            ],
          );
        }),
      ),
    );
  }
}
