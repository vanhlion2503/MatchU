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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: itemCount + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 18, top: 12),
            child: _ShimmerBlock(
              width: 180,
              height: 12,
              radius: 6,
              shimmer: shimmer,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _NearbyUserCardShimmer(
            shimmer: shimmer,
            background: background,
          ),
        );
      },
    );
  }
}

class _NearbyUserCardShimmer extends StatelessWidget {
  final _NearbyShimmerPalette shimmer;
  final Color background;

  const _NearbyUserCardShimmer({
    required this.shimmer,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBlock(width: 52, height: 52, radius: 26, shimmer: shimmer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ShimmerBlock(
                          width: double.infinity,
                          height: 16,
                          radius: 8,
                          shimmer: shimmer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ShimmerBlock(
                        width: 62,
                        height: 20,
                        radius: 12,
                        shimmer: shimmer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ShimmerBlock(
                    width: 120,
                    height: 12,
                    radius: 6,
                    shimmer: shimmer,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
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
