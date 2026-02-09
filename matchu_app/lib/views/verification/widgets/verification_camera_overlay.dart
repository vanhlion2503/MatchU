import 'dart:math' as math;

import 'package:flutter/material.dart';

class FaceVerificationMaskOverlay extends StatelessWidget {
  const FaceVerificationMaskOverlay({
    super.key,
    required this.isLiveness,
    required this.maskColor,
    required this.borderColor,
  });

  final bool isLiveness;
  final Color maskColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FaceMaskPainter(
        isLiveness: isLiveness,
        maskColor: maskColor,
        borderColor: borderColor,
      ),
    );
  }
}

class _FaceMaskPainter extends CustomPainter {
  _FaceMaskPainter({
    required this.isLiveness,
    required this.maskColor,
    required this.borderColor,
  });

  final bool isLiveness;
  final Color maskColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: size.width * (isLiveness ? 0.75 : 0.72),
      height: size.height * (isLiveness ? 0.5 : 0.48),
    );

    final maskPath =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addOval(ovalRect);

    canvas.drawPath(maskPath, Paint()..color = maskColor);

    canvas.drawOval(
      ovalRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLiveness ? 2.6 : 2.2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceMaskPainter oldDelegate) {
    return oldDelegate.isLiveness != isLiveness ||
        oldDelegate.maskColor != maskColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class FaceVerificationLivenessRingOverlay extends StatelessWidget {
  const FaceVerificationLivenessRingOverlay({
    super.key,
    required this.stepDone,
    required this.activeStep,
    required this.activeColor,
  });

  final List<bool> stepDone;
  final int activeStep;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LivenessRingPainter(
        stepDone: stepDone,
        activeStep: activeStep,
        activeColor: activeColor,
      ),
    );
  }
}

class _LivenessRingPainter extends CustomPainter {
  _LivenessRingPainter({
    required this.stepDone,
    required this.activeStep,
    required this.activeColor,
  });

  final List<bool> stepDone;
  final int activeStep;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: size.width * 0.8,
      height: size.height * 0.56,
    );

    final trackPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawOval(ovalRect, trackPaint);

    const stepCount = 4;
    const section = math.pi / 2;
    const gap = 0.2;

    for (int i = 0; i < stepCount; i++) {
      final done = i < stepDone.length && stepDone[i];
      final active = i == activeStep && !done;
      final color =
          done
              ? const Color(0xFF2DD4BF)
              : active
              ? activeColor
              : Colors.white.withValues(alpha: 0.22);

      canvas.drawArc(
        ovalRect,
        -math.pi / 2 + (i * section) + (gap / 2),
        section - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = done || active ? 5 : 4
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LivenessRingPainter oldDelegate) {
    if (oldDelegate.activeStep != activeStep ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.stepDone.length != stepDone.length) {
      return true;
    }

    for (int i = 0; i < stepDone.length; i++) {
      if (oldDelegate.stepDone[i] != stepDone[i]) {
        return true;
      }
    }
    return false;
  }
}
