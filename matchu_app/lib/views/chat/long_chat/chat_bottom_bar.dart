import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ChatBottomBar extends StatefulWidget {
  static final GlobalKey bottomBarKey = GlobalKey();

  final ChatController controller;

  const ChatBottomBar({super.key, required this.controller});

  @override
  State<ChatBottomBar> createState() => _ChatBottomBarState();
}

class _ChatBottomBarState extends State<ChatBottomBar> {
  static const Duration _kLeadingAnimDuration = Duration(milliseconds: 240);
  static const double _kIconSlot = 48;

  final GlobalKey _leadingActionsKey = GlobalKey();
  final GlobalKey _inputFieldKey = GlobalKey();
  bool _showLeftActions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.inputFocusNode.addListener(_onInputFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.inputFocusNode.removeListener(_onInputFocusChanged);
    super.dispose();
  }

  void _onInputFocusChanged() {
    if (!mounted) return;

    setState(() {
      _showLeftActions = false;
    });
  }

  void _collapseLeftActions() {
    if (!_showLeftActions) return;
    setState(() => _showLeftActions = false);
  }

  void _toggleLeftActions() {
    setState(() => _showLeftActions = !_showLeftActions);
  }

  double _leadingWidth(bool isInputFocused) {
    if (!isInputFocused) return _kIconSlot * 3;
    if (_showLeftActions) return _kIconSlot * 3;
    return _kIconSlot;
  }

  bool _isTapInside(GlobalKey key, Offset globalPosition) {
    final context = key.currentContext;
    if (context == null) return false;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;

    final localPosition = box.globalToLocal(globalPosition);
    return localPosition.dx >= 0 &&
        localPosition.dx <= box.size.width &&
        localPosition.dy >= 0 &&
        localPosition.dy <= box.size.height;
  }

  void _onBottomBarPointerDown(PointerDownEvent event) {
    if (!_showLeftActions) return;

    final tapPosition = event.position;
    if (_isTapInside(_leadingActionsKey, tapPosition)) return;
    if (_isTapInside(_inputFieldKey, tapPosition)) return;

    _collapseLeftActions();
  }

  Widget _buildCameraButton() {
    return IconButton(
      icon: const Icon(Iconsax.camera, size: 22),
      onPressed: () {
        HapticFeedback.lightImpact();
        widget.controller.hideEmoji();
        widget.controller.pickAndSendImage(source: ImageSource.camera);
      },
    );
  }

  Widget _buildGalleryButton() {
    return IconButton(
      icon: const Icon(Iconsax.gallery, size: 22),
      onPressed: () {
        HapticFeedback.lightImpact();
        widget.controller.hideEmoji();
        widget.controller.pickAndSendImage();
      },
    );
  }

  Widget _buildEmojiButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Iconsax.emoji_happy, size: 22),
      onPressed: () {
        HapticFeedback.lightImpact();
        FocusScope.of(context).unfocus();
        widget.controller.toggleEmoji();
      },
    );
  }

  Widget _buildToggleButton() {
    return IconButton(
      icon: const Icon(Icons.menu_rounded, size: 24),
      onPressed: _toggleLeftActions,
    );
  }

  Widget _buildLeadingContent(BuildContext context, bool isInputFocused) {
    if (!isInputFocused) {
      return OverflowBox(
        key: const ValueKey("leading_idle"),
        alignment: Alignment.centerLeft,
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: _kIconSlot,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCameraButton(),
            _buildGalleryButton(),
            _buildEmojiButton(context),
          ],
        ),
      );
    }

    if (!_showLeftActions) {
      return OverflowBox(
        key: const ValueKey("leading_compact"),
        alignment: Alignment.centerLeft,
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: _kIconSlot,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_buildToggleButton()],
        ),
      );
    }

    return OverflowBox(
      key: const ValueKey("leading_expanded"),
      alignment: Alignment.centerLeft,
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: _kIconSlot,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCameraButton(),
          _buildGalleryButton(),
          _buildEmojiButton(context),
        ],
      ),
    );
  }

  Widget _buildLeadingActions(BuildContext context, bool isInputFocused) {
    return AnimatedContainer(
      duration: _kLeadingAnimDuration,
      curve: Curves.easeOutCubic,
      width: _leadingWidth(isInputFocused),
      height: _kIconSlot,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: _kLeadingAnimDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: const Offset(-0.08, 0),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: _buildLeadingContent(context, isInputFocused),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return SafeArea(
      child: Obx(() {
        final isTyping = controller.isTyping.value;
        final isEditing = controller.editingMessage.value != null;
        final isInputFocused = controller.inputFocusNode.hasFocus;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onBottomBarPointerDown,
          child: Column(
            key: ChatBottomBar.bottomBarKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                final edit = controller.editingMessage.value;
                if (edit == null) return const SizedBox();

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        theme.brightness == Brightness.dark
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
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
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
              Obx(() {
                if (controller.editingMessage.value != null) {
                  return const SizedBox();
                }
                final reply = controller.replyingMessage.value;
                if (reply == null) return const SizedBox();

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        theme.brightness == Brightness.dark
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
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    KeyedSubtree(
                      key: _leadingActionsKey,
                      child: _buildLeadingActions(context, isInputFocused),
                    ),
                    Expanded(
                      child: ConstrainedBox(
                        key: _inputFieldKey,
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: controller.inputController,
                          focusNode: controller.inputFocusNode,
                          minLines: 1,
                          maxLines: null,
                          onChanged: (value) {
                            controller.onTypingChanged(value);
                            _collapseLeftActions();
                          },
                          onTap: () {
                            controller.hideEmoji();
                            _collapseLeftActions();
                          },
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
                                color:
                                    theme.brightness == Brightness.dark
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
                    IconButton(
                      icon: Icon(
                        isEditing ? Icons.check : Iconsax.send_1,
                        color:
                            (isTyping || isEditing)
                                ? color.primary
                                : color.outline,
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
              Obx(() {
                final scheme = Theme.of(context).colorScheme;

                return AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child:
                      controller.showEmoji.value
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
                                skinToneConfig: const SkinToneConfig(
                                  enabled: true,
                                ),
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}
