import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class OtherProfileShimmer extends StatelessWidget {
  const OtherProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surfaceContainerHighest;

    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.shimmerDarkBase : AppTheme.shimmerLightBase,
      highlightColor:
          isDark
              ? AppTheme.shimmerDarkHighlight
              : AppTheme.shimmerLightHighlight,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, 54),
                  child: Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 70),
            _Block(width: 150, height: 20, color: surface),
            const SizedBox(height: 10),
            _Block(width: 96, height: 14, color: surface),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _Block(height: 44, color: surface)),
                  const SizedBox(width: 12),
                  Expanded(child: _Block(height: 44, color: surface)),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  3,
                  (_) => Column(
                    children: [
                      _Block(width: 42, height: 18, color: surface),
                      const SizedBox(height: 8),
                      _Block(width: 68, height: 12, color: surface),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Block(width: 86, height: 30, radius: 15, color: surface),
                  _Block(width: 110, height: 30, radius: 15, color: surface),
                  _Block(width: 74, height: 30, radius: 15, color: surface),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(child: _Block(height: 16, color: surface)),
                  const SizedBox(width: 48),
                  Expanded(child: _Block(height: 16, color: surface)),
                ],
              ),
            ),
            ...List.generate(
              2,
              (_) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _Block(height: 150, radius: 18, color: surface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    this.width,
    required this.height,
    required this.color,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
