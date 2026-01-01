import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatelessWidget {
  final AnimationController controller;

  const AnimatedProgressBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 9,
        color: Colors.grey.shade200,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: controller.value.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1CABFF),
                      Color(0xFF5C6CFF),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
