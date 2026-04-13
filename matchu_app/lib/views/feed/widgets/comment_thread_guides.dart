import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CommentThreadGuides extends StatelessWidget {
  const CommentThreadGuides({
    super.key,
    required this.depth,
    required this.ancestorBranchContinues,
    required this.hasNextSibling,
    required this.hasChildren,
    required this.contentLeft,
    required this.avatarCenterY,
    required this.lineInsets,
    this.topPadding = 0,
    this.bottomPadding = 0,
    required this.color,
    required this.child,
  });

  final int depth;
  final List<bool> ancestorBranchContinues;
  final bool hasNextSibling;
  final bool hasChildren;
  final double contentLeft;
  final double avatarCenterY;
  final List<double> lineInsets;
  final double topPadding;
  final double bottomPadding;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CommentThreadGuidePainter(
                color: color,
                depth: depth,
                ancestorBranchContinues: ancestorBranchContinues,
                hasNextSibling: hasNextSibling,
                hasChildren: hasChildren,
                contentLeft: contentLeft,
                avatarCenterY: topPadding + avatarCenterY,
                lineInsets: lineInsets,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: contentLeft,
            top: topPadding,
            bottom: bottomPadding,
          ),
          child: child,
        ),
      ],
    );
  }
}

class _CommentThreadGuidePainter extends CustomPainter {
  const _CommentThreadGuidePainter({
    required this.color,
    required this.depth,
    required this.ancestorBranchContinues,
    required this.hasNextSibling,
    required this.hasChildren,
    required this.contentLeft,
    required this.avatarCenterY,
    required this.lineInsets,
  });

  final Color color;
  final int depth;
  final List<bool> ancestorBranchContinues;
  final bool hasNextSibling;
  final bool hasChildren;
  final double contentLeft;
  final double avatarCenterY;
  final List<double> lineInsets;

  @override
  void paint(Canvas canvas, Size size) {
    if (depth <= 0 && !hasChildren) return;

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

    if (depth > 0) {
      for (var level = 0; level < ancestorBranchContinues.length; level++) {
        if (!ancestorBranchContinues[level]) continue;

        final x = _lineXForLevel(level);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }

      final currentX = _lineXForLevel(depth - 1);
      final horizontalDelta = contentLeft - currentX;
      final horizontalDirection = horizontalDelta >= 0 ? 1.0 : -1.0;
      final elbowRadius = math.min(
        9.0,
        math.min(avatarCenterY, horizontalDelta.abs()),
      );
      final elbowJoinY = avatarCenterY - elbowRadius;

      if (elbowRadius > 0) {
        final elbowPath =
            Path()
              ..moveTo(currentX, 0)
              ..lineTo(currentX, elbowJoinY)
              ..quadraticBezierTo(
                currentX,
                avatarCenterY,
                currentX + (elbowRadius * horizontalDirection),
                avatarCenterY,
              )
              ..lineTo(contentLeft, avatarCenterY);
        canvas.drawPath(elbowPath, paint);
      } else {
        final elbowPath =
            Path()
              ..moveTo(currentX, 0)
              ..lineTo(currentX, avatarCenterY)
              ..lineTo(contentLeft, avatarCenterY);
        canvas.drawPath(elbowPath, paint);
      }

      if (hasNextSibling) {
        canvas.drawLine(
          Offset(currentX, elbowJoinY),
          Offset(currentX, size.height),
          paint,
        );
      }
    }

    if (hasChildren) {
      final childX = _lineXForLevel(depth);
      canvas.drawLine(
        Offset(childX, avatarCenterY),
        Offset(childX, size.height),
        paint,
      );
    }
  }

  double _lineXForLevel(int level) {
    if (lineInsets.isEmpty) return 0;
    if (level < lineInsets.length) return lineInsets[level];
    return lineInsets.last;
  }

  @override
  bool shouldRepaint(covariant _CommentThreadGuidePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.depth != depth ||
        !listEquals(
          oldDelegate.ancestorBranchContinues,
          ancestorBranchContinues,
        ) ||
        oldDelegate.hasNextSibling != hasNextSibling ||
        oldDelegate.hasChildren != hasChildren ||
        oldDelegate.contentLeft != contentLeft ||
        oldDelegate.avatarCenterY != avatarCenterY ||
        !listEquals(oldDelegate.lineInsets, lineInsets);
  }
}
