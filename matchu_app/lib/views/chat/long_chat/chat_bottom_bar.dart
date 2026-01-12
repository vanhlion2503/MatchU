import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ChatBottomBar extends StatelessWidget {
  static final GlobalKey bottomBarKey = GlobalKey();
  final ChatController controller;
  const ChatBottomBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return SafeArea(
      child: Obx(() {
        final isTyping = controller.isTyping.value;
        final isEditing = controller.editingMessage.value != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// ================= EDIT =================
            Obx(() {
              final edit = controller.editingMessage.value;
              if (edit == null) return const SizedBox();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Đang sửa",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            edit["text"] ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.cancelEdit,
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              );
            }),

            /// ================= REPLY =================
            Obx(() {
              if (controller.editingMessage.value != null) {
                return const SizedBox();
              }
              final reply = controller.replyingMessage.value;
              if (reply == null) return const SizedBox();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                    GestureDetector(
                      onTap: controller.cancelReply,
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              );
            }),

            /// ================= INPUT =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  /// IMAGE
                  IconButton(
                    icon: const Icon(Icons.image_outlined, size: 22),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      controller.hideEmoji();
                      controller.pickAndSendImage();
                    },
                  ),

                  /// 😊 EMOJI
                  IconButton(
                    icon: const Icon(Iconsax.emoji_happy, size: 22),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      FocusScope.of(context).unfocus();
                      controller.toggleEmoji();
                    },
                  ),

                  /// TEXT FIELD
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: controller.inputController,
                        focusNode: controller.inputFocusNode,
                        minLines: 1,
                        maxLines: null,
                        onChanged: controller.onTypingChanged,
                        onTap: controller.hideEmoji,
                        decoration: InputDecoration(
                          hintText: "Nhập tin nhắn...",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: theme.brightness == Brightness.dark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: color.primary),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  /// SEND
                  IconButton(
                    icon: Icon(
                      isEditing ? Icons.check : Iconsax.send_1,
                      color:
                          (isTyping || isEditing) ? color.primary : color.outline,
                      size: 26,
                    ),
                    onPressed: () {
                      final text = controller.inputController.text.trim();
                      if (text.isEmpty) return;

                      HapticFeedback.lightImpact();
                      controller.sendMessage();
                      controller.hideEmoji();
                    },
                  ),
                ],
              ),
            ),

            /// ================= EMOJI PICKER =================
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
                              iconColor:
                                  scheme.onSurface.withOpacity(0.6),
                              iconColorSelected: scheme.primary,
                            ),
                            bottomActionBarConfig: BottomActionBarConfig(
                              backgroundColor: scheme.surface,
                              buttonColor: scheme.primary,
                            ),
                            searchViewConfig: SearchViewConfig(
                              backgroundColor: scheme.surface,
                            ),
                            skinToneConfig:
                                const SkinToneConfig(enabled: true),
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
}
