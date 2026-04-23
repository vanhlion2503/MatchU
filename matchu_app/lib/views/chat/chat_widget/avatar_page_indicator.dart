import 'package:flutter/material.dart';

class AvatarPageIndicator extends StatelessWidget {
  final int count;
  final double page;

  const AvatarPageIndicator({
    super.key,
    required this.count,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox();

    const int visibleDots = 5;
    const double dotSize = 6;
    const double activeDotSize = 8;
    const double dotStep = 14;
    final double maxPage = (count - 1).toDouble();
    final double clampedPage = page.clamp(0.0, maxPage);

    final double viewportWidth = (visibleDots - 1) * dotStep + activeDotSize;
    final double trackHeight = activeDotSize + 2;
    final double leadingSpace = (viewportWidth - dotSize) / 2;
    final double trackWidth =
        leadingSpace * 2 + (count - 1) * dotStep + dotSize;
    final double offset = -(clampedPage * dotStep);

    return SizedBox(
      width: viewportWidth,
      height: trackHeight,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: offset,
              top: 0,
              child: SizedBox(
                width: trackWidth,
                height: trackHeight,
                child: _buildTrack(
                  count: count,
                  page: clampedPage,
                  dotSize: dotSize,
                  activeDotSize: activeDotSize,
                  dotStep: dotStep,
                  leadingSpace: leadingSpace,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrack({
    required int count,
    required double page,
    required double dotSize,
    required double activeDotSize,
    required double dotStep,
    required double leadingSpace,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(count, (index) {
        final double diff = (page - index).abs().clamp(0.0, 1.0);
        final double focus = Curves.easeOutCubic.transform(1 - diff);
        final double currentSize =
            dotSize + ((activeDotSize - dotSize) * focus);
        final double opacity = 0.3 + (0.7 * focus);
        final double centerX = leadingSpace + (index * dotStep) + (dotSize / 2);

        return Positioned(
          left: centerX - (currentSize / 2),
          top: (activeDotSize - currentSize) / 2,
          child: Container(
            width: currentSize,
            height: currentSize,
            decoration: BoxDecoration(
              color: const Color(0xFF2ED8FF).withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow:
                  focus > 0.6
                      ? [
                        BoxShadow(
                          color: const Color(
                            0xFF2ED8FF,
                          ).withValues(alpha: 0.25 * focus),
                          blurRadius: 6 * focus,
                          spreadRadius: 0.15 * focus,
                        ),
                      ]
                      : null,
            ),
          ),
        );
      }),
    );
  }
}
