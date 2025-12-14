import 'package:flutter/material.dart';

class AnimatedDots extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedDots({
    super.key,
    required this.color,
    this.size = 8,
  });

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
        final value = _controller.value * 3;
        final activeIndex = value.floor() % 3;
        final localProgress = value - value.floor(); // 0 → 1

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final isActive = i == activeIndex;

            /// 🔥 scale dot đang active
            final scale = isActive
                ? 1.0 + 0.4 * (1 - (localProgress - 0.5).abs() * 2)
                : 1.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: isActive ? 1 : 0.3,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
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
