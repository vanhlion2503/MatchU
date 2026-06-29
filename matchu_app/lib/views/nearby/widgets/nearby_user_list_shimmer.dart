import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class NearbyUserListShimmer extends StatelessWidget {
  final int itemCount;

  const NearbyUserListShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final shimmer = _NearbyShimmerPalette.of(context);
    final background = Theme.of(context).scaffoldBackgroundColor;
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.45);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: _ShimmerBlock(
            width: 180,
            height: 12,
            radius: 6,
            shimmer: shimmer,
          ),
        ),
        Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              children: [
                for (var index = 0; index < itemCount; index++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _NearbyUserListItemShimmer(
                      shimmer: shimmer,
                      background: background,
                    ),
                  ),
                  if (index != itemCount - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 82,
                      color: dividerColor,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NearbyUserListItemShimmer extends StatelessWidget {
  final _NearbyShimmerPalette shimmer;
  final Color background;

  const _NearbyUserListItemShimmer({
    required this.shimmer,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ShimmerBlock(width: 52, height: 52, radius: 26, shimmer: shimmer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBlock(
                  width: double.infinity,
                  height: 16,
                  radius: 8,
                  shimmer: shimmer,
                ),
                const SizedBox(height: 8),
                _ShimmerBlock(
                  width: 132,
                  height: 12,
                  radius: 6,
                  shimmer: shimmer,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ShimmerBlock(width: 66, height: 24, radius: 12, shimmer: shimmer),
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final _NearbyShimmerPalette shimmer;

  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.shimmer,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: shimmer.base,
      highlightColor: shimmer.highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmer.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _NearbyShimmerPalette {
  final Color base;
  final Color highlight;
  final Color surface;

  const _NearbyShimmerPalette({
    required this.base,
    required this.highlight,
    required this.surface,
  });

  factory _NearbyShimmerPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _NearbyShimmerPalette(
      base: isDark ? AppTheme.shimmerDarkBase : AppTheme.shimmerLightBase,
      highlight:
          isDark
              ? AppTheme.shimmerDarkHighlight
              : AppTheme.shimmerLightHighlight,
      surface: theme.colorScheme.surface,
    );
  }
}
