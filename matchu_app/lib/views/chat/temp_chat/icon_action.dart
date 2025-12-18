import 'package:flutter/material.dart';

class ActionIcon extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? backgroundColor;

  const ActionIcon({
    required this.child,
    required this.onTap,
    this.backgroundColor,
    super.key,
  });

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: backgroundColor ?? color.surfaceVariant,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
