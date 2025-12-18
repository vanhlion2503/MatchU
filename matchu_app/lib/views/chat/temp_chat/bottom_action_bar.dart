import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/temp_chat/icon_action.dart';

class BottomActionBar extends StatelessWidget {
  final TempChatController controller;
  BottomActionBar(this.controller, {super.key});

  final TextEditingController _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Obx(() {
          final isTyping = controller.isTyping.value;
          final liked = controller.userLiked.value != null;

          return Stack(
            alignment: Alignment.centerRight,
            children: [
              // ================= TEXT FIELD (TRẦN) =================
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: null,
                  onChanged: (v) {
                    controller.isTyping.value =
                        v.trim().isNotEmpty;
                  },
                  decoration: InputDecoration(
                    hintText: "Nhập tin nhắn...",
                    isDense: true,
                    contentPadding: EdgeInsets.only(
                      left: 12,
                      right: isTyping ? 56 : 96, // 🔑 chừa chỗ icon
                      top: 12,
                      bottom: 12,
                    ),
                  ),
                ),
              ),

              // ================= ACTION OVERLAY =================
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                child: () {
                  // ✈️ SEND
                  if (isTyping) {
                    return IconButton(
                      key: const ValueKey("send"),
                      icon: const Icon(Icons.send),
                      color: color.primary,
                      onPressed: () {
                        final text = _ctrl.text.trim();
                        if (text.isEmpty) return;
                        controller.send(text);
                        _ctrl.clear();
                        controller.isTyping.value = false;
                      },
                    );
                  }

                  // 👍 👎 LIKE
                  if (!liked) {
                    return Row(
                      key: const ValueKey("like"),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconAction(
                          icon: Icons.thumb_up,
                          color: AppTheme.successColor,
                          onTap: () => controller.like(true),
                        ),
                        const SizedBox(width: 4),
                        IconAction(
                          icon: Icons.thumb_down,
                          color: color.error,
                          onTap: () => controller.like(false),
                        ),
                      ],
                    );
                  }

                  return const SizedBox(key: ValueKey("empty"));
                }(),
              ),
            ],
          );
        }),
      ),
    );
  }
}
