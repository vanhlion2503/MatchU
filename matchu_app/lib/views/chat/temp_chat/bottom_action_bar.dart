import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/views/chat/temp_chat/icon_action.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:matchu_app/views/chat/temp_chat/widget/quick_message_bar.dart';
import 'package:matchu_app/views/chat/temp_chat/widget/telepathy_invite_bar.dart';


class BottomActionBar extends StatelessWidget {
  final TempChatController controller;
  BottomActionBar(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return SafeArea(
        child: Obx(() {
          final isTyping = controller.isTyping.value;
          final liked = controller.userLiked.value; // bool?
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TelepathyInviteBar(controller: controller),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Obx((){
                  final reply = controller.replyingMessage.value;
                  if (reply == null) return const SizedBox();
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    
                    child: Row(
                      children: [
                        // VẠCH TRÁI
                        Container(
                          width: 3,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // TEXT
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Đang trả lời",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                reply["text"],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // CLOSE
                        GestureDetector(
                          onTap: controller.cancelReply,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                
                }),
              ),
              
              QuickMessageBar(controller: controller),

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
                        controller: controller.inputController,
                        minLines: 1,
                        maxLines: null,
                        onChanged: controller.onTypingChanged,
                        onTap: () {
                          controller.hideEmoji();
                        },
                        decoration: InputDecoration(
                          hintText: "Nhập tin nhắn...",
                          isDense: true,
                          prefixIcon: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                                FocusScope.of(context).unfocus();
                                controller.toggleEmoji();
                              },
                              child: const Icon(
                                Iconsax.emoji_happy,
                                size: 22,
                              ),
                          ),
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
                              final text = controller.inputController.text.trim();
                              if (text.isEmpty) return;

                              final isEmojiOnly = _isEmojiOnly(text);

                              controller.send(
                                text,
                                type: isEmojiOnly ? "emoji" : "text",
                              );

                              controller.inputController.clear();
                              controller.stopTyping();
                              controller.hideEmoji();
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
              
              Obx(() {
                final scheme = Theme.of(context).colorScheme;

                return AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: controller.showEmoji.value
                      ? SizedBox(
                          height: 280,
                          width: MediaQuery.of(context).size.width,
                            child: EmojiPicker(
                              onEmojiSelected: (_, emoji) {
                                final ctrl = controller.inputController;
                                final text = ctrl.text;
                                final selection = ctrl.selection;

                                final newText = text.replaceRange(
                                  selection.start,
                                  selection.end,
                                  emoji.emoji,
                                );

                                ctrl.text = newText;
                                ctrl.selection = TextSelection.collapsed(
                                  offset: selection.start + emoji.emoji.length,
                                );

                                controller.isTyping.value = true;
                              },
                              config: Config(
                                height: 280,
                                emojiViewConfig: EmojiViewConfig(
                                  columns: 8,
                                  emojiSizeMax: 28,
                                  backgroundColor: scheme.surface,
                                ),
                                categoryViewConfig: CategoryViewConfig(
                                  backgroundColor: scheme.surface,
                                  indicatorColor: scheme.primary,
                                  iconColor: scheme.onSurface.withOpacity(0.6),
                                  iconColorSelected: scheme.primary,
                                ),
                                bottomActionBarConfig: BottomActionBarConfig(
                                  backgroundColor: scheme.surface,
                                  buttonColor: scheme.primary,
                                ),
                                searchViewConfig: SearchViewConfig(
                                  backgroundColor: scheme.surface,
                                ),
                                skinToneConfig: const SkinToneConfig(enabled: true),
                              ),
                            ),
                        )
                      : const SizedBox.shrink(),
                );
              }),

            ],
          );
        }),
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
    bool _isEmojiOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final emojiRegex = RegExp(
      r'^(?:\p{Emoji_Presentation}|\p{Extended_Pictographic})+$',
      unicode: true,
    );

    return emojiRegex.hasMatch(trimmed);
  }

}
