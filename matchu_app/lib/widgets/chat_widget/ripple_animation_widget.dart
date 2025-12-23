import 'package:flutter/material.dart';

class RippleAnimation extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final double size;

  const RippleAnimation({
    super.key,
    required this.animation,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          return CustomPaint(
            painter: _RadarRipplePainter(
              progress: animation.value,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _RadarRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarRipplePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    /// 🔥 TÂM CAO → LAN XUỐNG DƯỚI MẠNH
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    /// 🔥 BÁN KÍNH RẤT LỚN
    final maxRadius = size.height * 1.4;

    for (int i = 0; i < 3; i++) {
      /// vòng radar lệch pha
      final t = (progress + i * 0.5) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1 - t).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
