import 'package:flutter/material.dart';

class FaceCaptureOverlay extends StatelessWidget {
  const FaceCaptureOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.helperText,
  });

  final String title;
  final String subtitle;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ovalWidth = constraints.maxWidth * 0.68;
          final ovalHeight = constraints.maxHeight * 0.48;
          final topPadding = constraints.maxHeight * 0.13;
          final helperBottom = constraints.maxHeight * 0.23;

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.58),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0, 0.28, 0.62, 1],
                  ),
                ),
              ),
              const Positioned(top: 22, left: 22, child: _DecorativeDot()),
              const Positioned(top: 22, right: 22, child: _DecorativeDot()),
              Positioned(
                top: topPadding,
                left: 22,
                right: 22,
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                child: Container(
                  width: ovalWidth,
                  height: ovalHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.82),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: helperBottom,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      helperText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DecorativeDot extends StatelessWidget {
  const _DecorativeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }
}
