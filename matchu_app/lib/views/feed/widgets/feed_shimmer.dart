import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class FeedShimmer extends StatelessWidget {
  const FeedShimmer({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final palette = _FeedShimmerPalette.of(context);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => _FeedCardSkeleton(palette: palette),
    );
  }
}

class _FeedCardSkeleton extends StatelessWidget {
  const _FeedCardSkeleton({required this.palette});

  final _FeedShimmerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBlock(
                width: 48,
                height: 48,
                radius: 24,
                palette: palette,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBlock(
                      width: 140,
                      height: 14,
                      radius: 7,
                      palette: palette,
                    ),
                    const SizedBox(height: 8),
                    _ShimmerBlock(
                      width: 94,
                      height: 12,
                      radius: 6,
                      palette: palette,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ShimmerBlock(
            width: double.infinity,
            height: 12,
            radius: 6,
            palette: palette,
          ),
          const SizedBox(height: 8),
          _ShimmerBlock(width: 210, height: 12, radius: 6, palette: palette),
          const SizedBox(height: 14),
          _ShimmerBlock(
            width: double.infinity,
            height: 220,
            radius: 20,
            palette: palette,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ShimmerBlock(
                  width: double.infinity,
                  height: 42,
                  radius: 14,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShimmerBlock(
                  width: double.infinity,
                  height: 42,
                  radius: 14,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShimmerBlock(
                  width: double.infinity,
                  height: 42,
                  radius: 14,
                  palette: palette,
                ),
              ),
            ],
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
    required this.palette,
  });

  final double width;
  final double height;
  final double radius;
  final _FeedShimmerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: palette.base,
      highlightColor: palette.highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _FeedShimmerPalette {
  const _FeedShimmerPalette({
    required this.base,
    required this.highlight,
    required this.surface,
    required this.cardBackground,
    required this.cardBorder,
  });

  final Color base;
  final Color highlight;
  final Color surface;
  final Color cardBackground;
  final Color cardBorder;

  factory _FeedShimmerPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _FeedShimmerPalette(
      base: isDark ? AppTheme.shimmerDarkBase : AppTheme.shimmerLightBase,
      highlight:
          isDark
              ? AppTheme.shimmerDarkHighlight
              : AppTheme.shimmerLightHighlight,
      surface: theme.colorScheme.surface,
      cardBackground:
          isDark ? const Color(0xFF141821) : const Color(0xFFFFFFFF),
      cardBorder: isDark ? AppTheme.darkBorder : const Color(0xFFE8EEF5),
    );
  }
}
