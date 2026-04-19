import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:shimmer/shimmer.dart';

enum CommentShimmerVariant { sheet, detail }

class CommentSectionShimmer extends StatelessWidget {
  const CommentSectionShimmer({
    super.key,
    required this.variant,
    this.itemCount = 4,
  });

  final CommentShimmerVariant variant;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final colors = _CommentShimmerColors.of(context, palette);

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: colors.base,
        highlightColor: colors.highlight,
        period: const Duration(milliseconds: 1250),
        child:
            variant == CommentShimmerVariant.sheet
                ? _SheetCommentShimmer(itemCount: itemCount, colors: colors)
                : _DetailCommentShimmer(itemCount: itemCount, colors: colors),
      ),
    );
  }
}

class CommentLoadMoreShimmer extends StatelessWidget {
  const CommentLoadMoreShimmer({
    super.key,
    required this.variant,
    this.itemCount = 1,
    this.includeOuterPadding = true,
  });

  final CommentShimmerVariant variant;
  final int itemCount;
  final bool includeOuterPadding;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final colors = _CommentShimmerColors.of(context, palette);
    final child =
        variant == CommentShimmerVariant.sheet
            ? Column(
              children: [
                for (var index = 0; index < itemCount; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _SheetCommentSkeleton(
                    colors: colors,
                    bodyWidthFactor: _bodyWidthFactorFor(index + 2),
                  ),
                ],
              ],
            )
            : Column(
              children: [
                for (var index = 0; index < itemCount; index++) ...[
                  if (index > 0)
                    Divider(height: 1, thickness: 1, color: colors.divider),
                  _DetailCommentSkeleton(
                    colors: colors,
                    bodyWidthFactor: _bodyWidthFactorFor(index + 1),
                    secondaryWidthFactor: _secondaryBodyWidthFactorFor(
                      index + 1,
                    ),
                  ),
                ],
              ],
            );

    final paddedChild =
        includeOuterPadding
            ? variant == CommentShimmerVariant.sheet
                ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: child,
                )
                : Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  child: child,
                )
            : child;

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: colors.base,
        highlightColor: colors.highlight,
        period: const Duration(milliseconds: 1250),
        child: paddedChild,
      ),
    );
  }
}

class _SheetCommentShimmer extends StatelessWidget {
  const _SheetCommentShimmer({required this.itemCount, required this.colors});

  final int itemCount;
  final _CommentShimmerColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ShimmerBlock(
              width: 108,
              height: 30,
              radius: 999,
              colors: colors,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder:
                (_, index) => _SheetCommentSkeleton(
                  colors: colors,
                  bodyWidthFactor: _bodyWidthFactorFor(index),
                ),
          ),
        ),
      ],
    );
  }
}

class _DetailCommentShimmer extends StatelessWidget {
  const _DetailCommentShimmer({required this.itemCount, required this.colors});

  final int itemCount;
  final _CommentShimmerColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ShimmerBlock(
              width: 108,
              height: 30,
              radius: 999,
              colors: colors,
            ),
          ),
        ),
        for (var index = 0; index < itemCount; index++) ...[
          if (index > 0)
            Divider(height: 1, thickness: 1, color: colors.divider),
          _DetailCommentSkeleton(
            colors: colors,
            bodyWidthFactor: _bodyWidthFactorFor(index),
            secondaryWidthFactor: _secondaryBodyWidthFactorFor(index),
          ),
        ],
      ],
    );
  }
}

class _SheetCommentSkeleton extends StatelessWidget {
  const _SheetCommentSkeleton({
    required this.colors,
    required this.bodyWidthFactor,
  });

  final _CommentShimmerColors colors;
  final double bodyWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerBlock(width: 36, height: 36, radius: 18, colors: colors),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBlock(
                  width: 108,
                  height: 13,
                  radius: 7,
                  colors: colors,
                ),
                const SizedBox(height: 7),
                _ShimmerBlock(width: 76, height: 10, radius: 6, colors: colors),
                const SizedBox(height: 12),
                FractionallySizedBox(
                  widthFactor: 1,
                  child: _ShimmerBlock(
                    width: double.infinity,
                    height: 11,
                    radius: 6,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: bodyWidthFactor,
                  child: _ShimmerBlock(
                    width: double.infinity,
                    height: 11,
                    radius: 6,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetaPlaceholder(colors: colors, width: 30),
                    const SizedBox(width: 16),
                    _MetaPlaceholder(colors: colors, width: 44),
                  ],
                ),
                const SizedBox(height: 10),
                _MetaPlaceholder(colors: colors, width: 96, iconSize: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailCommentSkeleton extends StatelessWidget {
  const _DetailCommentSkeleton({
    required this.colors,
    required this.bodyWidthFactor,
    required this.secondaryWidthFactor,
  });

  final _CommentShimmerColors colors;
  final double bodyWidthFactor;
  final double secondaryWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBlock(width: 38, height: 38, radius: 19, colors: colors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ShimmerBlock(
                      width: 112,
                      height: 13,
                      radius: 7,
                      colors: colors,
                    ),
                    const SizedBox(width: 10),
                    _ShimmerBlock(
                      width: 42,
                      height: 10,
                      radius: 6,
                      colors: colors,
                    ),
                    const Spacer(),
                    _ShimmerBlock(
                      width: 18,
                      height: 18,
                      radius: 9,
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: 1,
                  child: _ShimmerBlock(
                    width: double.infinity,
                    height: 11,
                    radius: 6,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: bodyWidthFactor,
                  child: _ShimmerBlock(
                    width: double.infinity,
                    height: 11,
                    radius: 6,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: secondaryWidthFactor,
                  child: _ShimmerBlock(
                    width: double.infinity,
                    height: 11,
                    radius: 6,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetaPlaceholder(colors: colors, width: 26),
                    const SizedBox(width: 18),
                    _MetaPlaceholder(colors: colors, width: 38),
                    const SizedBox(width: 18),
                    _MetaPlaceholder(colors: colors, width: 82),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPlaceholder extends StatelessWidget {
  const _MetaPlaceholder({
    required this.colors,
    required this.width,
    this.iconSize = 14,
  });

  final _CommentShimmerColors colors;
  final double width;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShimmerBlock(
          width: iconSize,
          height: iconSize,
          radius: iconSize / 2,
          colors: colors,
        ),
        const SizedBox(width: 6),
        _ShimmerBlock(width: width, height: 10, radius: 6, colors: colors),
      ],
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
  final _CommentShimmerColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _CommentShimmerColors {
  const _CommentShimmerColors({
    required this.base,
    required this.highlight,
    required this.surface,
    required this.cardSurface,
    required this.cardBorder,
    required this.divider,
  });

  final Color base;
  final Color highlight;
  final Color surface;
  final Color cardSurface;
  final Color cardBorder;
  final Color divider;

  factory _CommentShimmerColors.of(BuildContext context, FeedPalette palette) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _CommentShimmerColors(
      base: isDark ? AppTheme.shimmerDarkBase : AppTheme.shimmerLightBase,
      highlight:
          isDark
              ? AppTheme.shimmerDarkHighlight
              : AppTheme.shimmerLightHighlight,
      surface: isDark ? const Color(0xFF171C27) : const Color(0xFFF1F3F6),
      cardSurface: palette.surface.withValues(alpha: isDark ? 0.92 : 1),
      cardBorder: palette.border,
      divider: palette.border,
    );
  }
}

double _bodyWidthFactorFor(int index) {
  const values = <double>[0.72, 0.58, 0.82, 0.66, 0.61];
  return values[index % values.length];
}

double _secondaryBodyWidthFactorFor(int index) {
  const values = <double>[0.46, 0.68, 0.54, 0.6, 0.49];
  return values[index % values.length];
}
