import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matchu_app/models/reaction_icon.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ReactionPicker extends StatefulWidget {
  final void Function(String reactionId) onSelect;

  const ReactionPicker({super.key, required this.onSelect});

  static List<ReactionIcon> reactions = [
    ReactionIcon(
      id: "like",
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.blue,
            width: 1.5,
          ),
          color: Colors.blue, // nền nhẹ
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.thumb_up,
          size: 18,
          color: Colors.white,
        ),
      ),
    ),

    ReactionIcon(
      id: "love",
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.red,
            width: 1.5,
          ),
          color: Colors.red,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.favorite,
          size: 18,
          color: Colors.white,
        ),
      ),
    ),

    ReactionIcon(
      id: "haha",
      icon: Text("😂", style: TextStyle(fontSize: 26)),
    ),

    ReactionIcon(
      id: "wow",
      icon: Text("😮", style: TextStyle(fontSize: 26)),
    ),
    ReactionIcon(
      id: "lo",
      icon: Text("😢", style: TextStyle(fontSize: 26)),
    ),
    ReactionIcon(
      id: "gian",
      icon: Text("😡", style: TextStyle(fontSize: 26)),
    ),
  ];


  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker> {
  String? _hoverId;

  void _setHover(String id) {
    if (_hoverId == id) return;
    HapticFeedback.selectionClick();
    setState(() => _hoverId = id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black.withOpacity(0.15),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ReactionPicker.reactions.map((reaction) {
            final isHover = _hoverId == reaction.id;

            return GestureDetector(
              onTapDown: (_) => _setHover(reaction.id),
              onTapCancel: () => setState(() => _hoverId = null),
              onTap: () {
                widget.onSelect(reaction.id);
                setState(() => _hoverId = null);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedScale(
                  scale: isHover ? 1.45 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  child: reaction.icon,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}



