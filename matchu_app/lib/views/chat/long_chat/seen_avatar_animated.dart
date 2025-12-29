import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/chat_widget/user_avatar.dart';

class SeenAvatarAnimated extends StatelessWidget {
  final String? userId;
  final double size;

  const SeenAvatarAnimated({
    super.key,
    required this.userId,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: userId == null
          ? const SizedBox(
              key: ValueKey("empty"),
              width: 14,
              height: 14,
            )
          : SizedBox(
              key: ValueKey("avatar"),
              width: size,
              height: size,
              child: UserAvatar(userId: userId!),
            ),
    );
  }
}
