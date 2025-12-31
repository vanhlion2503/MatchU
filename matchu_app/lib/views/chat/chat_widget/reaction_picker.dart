import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ReactionPicker extends StatelessWidget {
  final void Function(String emoji) onSelect;

  const ReactionPicker({super.key, required this.onSelect});

  static const emojis = ["👍", "❤️", "🥰", "😂", "😮", "😢", "😡"];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final backgroundColor = isDark
        ? AppTheme.darkBorder
        : const Color(0xFFF4F6F8);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black.withOpacity(0.15),
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((e) {
            return GestureDetector(
              onTap: () => onSelect(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
