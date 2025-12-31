import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ReactionPicker extends StatefulWidget {
  final void Function(String emoji) onSelect;

  const ReactionPicker({super.key, required this.onSelect});

  static const emojis = ["👍", "❤️", "🥰", "😂", "😮", "😢", "😡"];

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker> {
  String? _hoverEmoji;

  void _setHover(String emoji) {
    if (_hoverEmoji == emoji) return;

    // 📳 rung nhẹ khi đổi emoji
    HapticFeedback.selectionClick();
    setState(() => _hoverEmoji = emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor =
        isDark ? AppTheme.darkBorder : const Color(0xFFF4F6F8);

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
          children: ReactionPicker.emojis.map((emoji) {
            final isHover = _hoverEmoji == emoji;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,

              /// 👆 giữ tay → hover + haptic
              onTapDown: (_) => _setHover(emoji),

              /// ❌ rời / cancel
              onTapCancel: () => setState(() => _hoverEmoji = null),

              /// ✋ nhấc tay → chọn
              onTap: () {
                widget.onSelect(emoji);
                setState(() => _hoverEmoji = null);
              },

              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedScale(
                  scale: isHover ? 1.45 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: isHover ? 1.0 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
