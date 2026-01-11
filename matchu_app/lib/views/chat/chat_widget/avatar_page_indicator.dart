import 'dart:ui';
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
    const int visibleDots = 5;
    const double dotHeight = 6;
    const double dotSpacing = 14; // width + margin

    if (count == 0) return const SizedBox();

    final double viewportWidth = visibleDots * dotSpacing;
    final double trackWidth = count * dotSpacing;

    // ===== offset theo page (continuous) =====
    double offset = -page * dotSpacing;
    final double maxOffset = trackWidth - viewportWidth;
    if (maxOffset <= 0) {
      offset = 0;
    } else {
      offset = offset.clamp(-maxOffset, 0);
    }

    return SizedBox(
      width: viewportWidth,
      height: dotHeight + 8,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: offset,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: trackWidth, // 🔥 QUAN TRỌNG
                child: _buildTrack(page),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrack(double page) {
    return Stack(
      children: List.generate(count, (index) {
        final double diff = (page - index).abs();
        final double t =
            Curves.easeOut.transform(diff.clamp(0, 1));

        final double width = lerpDouble(22, 6, t)!;
        final double opacity = lerpDouble(1, 0.25, t)!;

        return Positioned(
          left: index * 14, // 👈 vị trí tuyệt đối
          top: 0,
          child: Container(
            width: width,
            height: 6,
            decoration: BoxDecoration(
              color:
                  const Color(0xFF2ED8FF).withOpacity(opacity),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }),
    );
  }
}
