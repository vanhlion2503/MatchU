import 'package:flutter/material.dart';
import 'package:matchu_app/widgets/animated_dots.dart';

class TypingBubbleRowPermanent extends StatelessWidget {
  const TypingBubbleRowPermanent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 36), // chừa avatar
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Container(
              width: 52,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surface
                    : const Color(0xFFEEF2F7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: AnimatedDots(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                size: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
