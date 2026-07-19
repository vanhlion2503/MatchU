import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton shared by user search, followers and following lists.
class UserListShimmer extends StatelessWidget {
  const UserListShimmer({
    super.key,
    this.itemCount = 7,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppTheme.shimmerDarkBase : AppTheme.shimmerLightBase;
    final highlightColor =
        isDark ? AppTheme.shimmerDarkHighlight : AppTheme.shimmerLightHighlight;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (_, index) => const _UserListItemSkeleton(),
      ),
    );
  }
}

class _UserListItemSkeleton extends StatelessWidget {
  const _UserListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.52,
                  child: _SkeletonLine(color: surface, height: 16),
                ),
                const SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: 0.34,
                  child: _SkeletonLine(color: surface, height: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
