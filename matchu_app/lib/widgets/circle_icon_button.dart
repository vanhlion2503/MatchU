import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

class CircleIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;

  final Offset offset;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const CircleIconButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.offset = const Offset(0, 0),
    this.size = 40,
    this.iconSize = 18,
    this.iconColor,
  });

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Transform.translate(
      offset: widget.offset,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.scaffoldBackgroundColor,
              border: Border.all(
                color: isDark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    isDark ? 0.35 : 0.06,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.iconColor ??
                  theme.colorScheme.onBackground,
            ),
          ),
        ),
      ),
    );
  }
}
