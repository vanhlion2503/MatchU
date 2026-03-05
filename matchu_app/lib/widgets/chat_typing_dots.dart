import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChatTypingDots extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double spacing;
  final Duration duration;

  const ChatTypingDots({
    super.key,
    required this.color,
    this.dotSize = 5,
    this.spacing = 4,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  State<ChatTypingDots> createState() => _ChatTypingDotsState();
}

class _ChatTypingDotsState extends State<ChatTypingDots>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 3;
  static const double _phaseStep = 0.16;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant ChatTypingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration == widget.duration) return;

    _controller.duration = widget.duration;
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_dotCount, (index) {
            final progress = (_controller.value + (index * _phaseStep)) % 1;
            final wave = 0.5 + (0.5 * math.sin(progress * 2 * math.pi));
            final scale = 0.86 + (wave * 0.24);
            final opacity = 0.28 + (wave * 0.72);
            final translateY = 1.8 - (wave * 3.6);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: widget.dotSize),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
