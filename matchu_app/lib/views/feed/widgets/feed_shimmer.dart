import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:shimmer/shimmer.dart';

class FeedShimmer extends StatelessWidget {
  const FeedShimmer({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final shimmer = _FeedShimmerColors.of(context);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
      itemCount: itemCount,
      itemBuilder: (_, index) {
        return Column(
          children: [
            if (index > 0)
              Padding(
                padding: const EdgeInsets.only(left: 68, right: 16),
                child: Divider(height: 1, thickness: 1, color: palette.border),
              ),
            _PostSkeleton(
              palette: palette,
              colors: shimmer,
              showMedia: index.isEven,
            ),
          ],
        );
      },
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton({
    required this.palette,
    required this.colors,
    required this.showMedia,
  });

  final FeedPalette palette;
  final _FeedShimmerColors colors;
  final bool showMedia;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _ShimmerBlock(
                  width: 40,
                  height: 40,
                  radius: 20,
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _ShimmerBlock(
                  width: 1.4,
                  height: 28,
                  radius: 999,
                  colors: colors,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShimmerBlock(
                      width: 12,
                      height: 12,
                      radius: 6,
                      colors: colors,
                    ),
                    const SizedBox(width: 4),
                    _ShimmerBlock(
                      width: 12,
                      height: 12,
                      radius: 6,
                      colors: colors,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ShimmerBlock(
                      width: 118,
                      height: 14,
                      radius: 7,
                      colors: colors,
                    ),
                    const Spacer(),
                    _ShimmerBlock(
                      width: 28,
                      height: 12,
                      radius: 6,
                      colors: colors,
                    ),
                    const SizedBox(width: 8),
                    _ShimmerBlock(
                      width: 18,
                      height: 18,
                      radius: 9,
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ShimmerBlock(width: 76, height: 11, radius: 6, colors: colors),
                const SizedBox(height: 10),
                _ShimmerBlock(
                  width: double.infinity,
                  height: 12,
                  radius: 6,
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _ShimmerBlock(
                  width: 220,
                  height: 12,
                  radius: 6,
                  colors: colors,
                ),
                if (showMedia) ...[
                  const SizedBox(height: 12),
                  _ShimmerBlock(
                    width: double.infinity,
                    height: 220,
                    radius: 18,
                    colors: colors,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ShimmerBlock(
                      width: 24,
                      height: 24,
                      radius: 12,
                      colors: colors,
                    ),
                    const SizedBox(width: 12),
                    _ShimmerBlock(
                      width: 24,
                      height: 24,
                      radius: 12,
                      colors: colors,
                    ),
                    const SizedBox(width: 12),
                    _ShimmerBlock(
                      width: 24,
                      height: 24,
                      radius: 12,
                      colors: colors,
                    ),
                    const SizedBox(width: 12),
                    _ShimmerBlock(
                      width: 24,
                      height: 24,
                      radius: 12,
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ShimmerBlock(
                  width: 148,
                  height: 11,
                  radius: 6,
                  colors: colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.colors,
  });

  final double width;
  final double height;
  final double radius;
  final _FeedShimmerColors colors;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: colors.base,
      highlightColor: colors.highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _FeedShimmerColors {
  const _FeedShimmerColors({
    required this.base,
    required this.highlight,
    required this.surface,
  });

  final Color base;
  final Color highlight;
  final Color surface;

  factory _FeedShimmerColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _FeedShimmerColors(
      base: isDark ? AppTheme.shimmerDarkBase : AppTheme.shimmerLightBase,
      highlight:
          isDark
              ? AppTheme.shimmerDarkHighlight
              : AppTheme.shimmerLightHighlight,
      surface: isDark ? const Color(0xFF171C27) : const Color(0xFFF5F5F5),
    );
  }
}
