import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class ReputationViewShimmer extends StatelessWidget {
  const ReputationViewShimmer({super.key, this.taskCount = 5});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final shimmer = _ReputationShimmerPalette.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          _HeaderSkeleton(shimmer: shimmer),
          const SizedBox(height: 16),
          Row(
            children: [
              _ShimmerBlock(
                width: 138,
                height: 20,
                radius: 10,
                shimmer: shimmer,
              ),
              const Spacer(),
              _ShimmerBlock(
                width: 104,
                height: 26,
                radius: 13,
                shimmer: shimmer,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < taskCount; i++) ...[
            _TaskCardSkeleton(shimmer: shimmer),
            if (i != taskCount - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton({required this.shimmer});

  final _ReputationShimmerPalette shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4B79), Color(0xFFFF6D2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44EC4B79),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeaderCircle(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBlock(
                      width: 92,
                      height: 11,
                      radius: 6,
                      shimmer: shimmer,
                    ),
                    const SizedBox(height: 8),
                    _ShimmerBlock(
                      width: 160,
                      height: 16,
                      radius: 8,
                      shimmer: shimmer,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ShimmerBlock(
                width: 66,
                height: 28,
                radius: 14,
                shimmer: shimmer,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ShimmerBlock(
                width: 98,
                height: 48,
                radius: 16,
                shimmer: shimmer,
              ),
              const SizedBox(width: 8),
              _ShimmerBlock(
                width: 52,
                height: 22,
                radius: 10,
                shimmer: shimmer,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _ShimmerBlock(
                width: 112,
                height: 14,
                radius: 7,
                shimmer: shimmer,
              ),
              const Spacer(),
              _ShimmerBlock(width: 82, height: 14, radius: 7, shimmer: shimmer),
            ],
          ),
          const SizedBox(height: 10),
          _ShimmerBlock(
            width: double.infinity,
            height: 8,
            radius: 99,
            shimmer: shimmer,
          ),
        ],
      ),
    );
  }
}

class _HeaderCircle extends StatelessWidget {
  const _HeaderCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
    );
  }
}

class _TaskCardSkeleton extends StatelessWidget {
  const _TaskCardSkeleton({required this.shimmer});

  final _ReputationShimmerPalette shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shimmer.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: shimmer.cardBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _ShimmerBlock(
                      width: 40,
                      height: 40,
                      radius: 16,
                      shimmer: shimmer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBlock(
                            width: 150,
                            height: 16,
                            radius: 8,
                            shimmer: shimmer,
                          ),
                          const SizedBox(height: 6),
                          _ShimmerBlock(
                            width: 180,
                            height: 12,
                            radius: 6,
                            shimmer: shimmer,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ShimmerBlock(width: 86, height: 16, radius: 8, shimmer: shimmer),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ShimmerBlock(
                      width: 74,
                      height: 12,
                      radius: 6,
                      shimmer: shimmer,
                    ),
                    const SizedBox(height: 4),
                    _ShimmerBlock(
                      width: double.infinity,
                      height: 6,
                      radius: 99,
                      shimmer: shimmer,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ShimmerBlock(
                width: 96,
                height: 32,
                radius: 12,
                shimmer: shimmer,
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
    required this.shimmer,
  });

  final double width;
  final double height;
  final double radius;
  final _ReputationShimmerPalette shimmer;

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

class _ReputationShimmerPalette {
  const _ReputationShimmerPalette({
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

  factory _ReputationShimmerPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _ReputationShimmerPalette(
      base: isDark ? AppTheme.shimmerDarkBase : AppTheme.shimmerLightBase,
      highlight:
          isDark
              ? AppTheme.shimmerDarkHighlight
              : AppTheme.shimmerLightHighlight,
      surface: theme.colorScheme.surface,
      cardBackground:
          isDark ? const Color.fromARGB(255, 15, 21, 37) : Colors.white,
      cardBorder:
          isDark
              ? const Color.fromARGB(66, 110, 118, 138)
              : const Color(0xFFE9EEF5),
    );
  }
}
