import 'package:flutter/material.dart';


class DashedLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  DashedLinePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    const dashWidth = 8.0;
    const dashSpace = 12.0;
    final dashTotal = dashWidth + dashSpace;

    // 👇 đảm bảo progress luôn là double hợp lệ
    final offset = dashTotal * progress;

    double startX = -dashTotal + offset;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashTotal;
    }
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
