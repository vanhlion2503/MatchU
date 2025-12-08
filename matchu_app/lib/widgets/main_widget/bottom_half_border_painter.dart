import 'package:flutter/material.dart';

class BottomHalfBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  BottomHalfBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Chỉ vẽ nửa dưới hình tròn (180° → 360°)
    canvas.drawArc(
      rect,
      3.14159,      // π rad  = 180° (bắt đầu ở bên trái)
      3.14159,      // π rad  = 180° cung còn lại
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
