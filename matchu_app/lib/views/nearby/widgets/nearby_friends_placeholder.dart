import 'dart:math';

import 'package:flutter/material.dart';

class NearbyFriendsPlaceholder extends StatelessWidget {
  const NearbyFriendsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  gridColor: colorScheme.outlineVariant,
                  ringColor: colorScheme.primary,
                ),
                child: Container(color: colorScheme.surfaceVariant),
              ),
            ),
            Positioned(
              top: 90,
              left: -60,
              right: -60,
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    border: Border.all(color: colorScheme.surface),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: 120,
              bottom: -40,
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    border: Border.all(color: colorScheme.surface),
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      "Vi tri ban be (minh hoa)",
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color gridColor;
  final Color ringColor;

  _GridPainter({
    required this.gridColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.7)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = ringColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, min(size.width, size.height) * 0.18, ringPaint);
    canvas.drawCircle(center, min(size.width, size.height) * 0.3, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
