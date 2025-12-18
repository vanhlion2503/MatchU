import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/views/chat/temp_chat/icon_action.dart';
import 'package:matchu_app/theme/app_theme.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Obx(() {
          final isTyping = controller.isTyping.value;
          final liked = controller.userLiked.value; // bool?

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ❌ THOÁT
                  ActionIcon(
                    onTap: () => _confirmLeave(context),
                    child: Icon(
                      Iconsax.close_circle,
                      color: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                      size: 32,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ================= INPUT =================
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
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
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: theme.brightness ==
                                      Brightness.dark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(20),
                            borderSide:
                                BorderSide(color: color.primary),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ================= LIKE / SEND =================
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                        child: FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                      );
                    },
                    child: isTyping
                        // ✈️ SEND
                        ? ActionIcon(
                            key: const ValueKey("send"),
                            onTap: () {
                              final text = _ctrl.text.trim();
                              if (text.isEmpty) return;
                              controller.send(text);
                              _ctrl.clear();
                              controller.isTyping.value = false;
                            },
                            child: Icon(
                              Iconsax.send_1,
                              color: color.primary,
                              size: 28,
                            ),
                          )
                        // ❤️ LIKE (outline → filled, 1 chiều)
                        : ActionIcon(
                            key: const ValueKey("like"),
                            onTap: () {
                              if (liked == true) return; // ❌ không cho tắt
                              HapticFeedback.lightImpact();
                              controller.like(true);
                            },
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              scale: liked == true ? 1.2 : 1.0,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                transitionBuilder: (child, anim) {
                                  return ScaleTransition(
                                    scale: anim,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  liked == true
                                      ? Iconsax.lovely5 // ❤️ filled
                                      : Iconsax.lovely, // 🤍 outline
                                  key: ValueKey(liked == true),
                                  color: Colors.red,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                  ),

                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  // ================= CONFIRM THOÁT =================
  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Thoát phòng"),
        content:
            const Text("Bạn có chắc muốn thoát phòng không?"),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Huỷ"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text("Thoát"),
          ),
        ],
      ),
    );

    if (ok == true) {
      controller.leaveByDislike();
    }
  }
}
