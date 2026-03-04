import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/temp_chat/icon_action.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/quick_message_bar.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/telepathy_invite_bar.dart';
import 'package:matchu_app/views/chat/temp_chat/widgets/game_sheet_item.dart';
import 'package:matchu_app/views/chat/temp_chat/word_chain/word_chain_invite_bar.dart';

class BottomActionBar extends StatefulWidget {
  final TempChatController controller;

  const BottomActionBar(this.controller, {super.key});

  @override
  State<BottomActionBar> createState() => _BottomActionBarState();
}

class _BottomActionBarState extends State<BottomActionBar> {
  static const Duration _kLeadingAnimDuration = Duration(milliseconds: 240);
  static const double _kActionSize = ActionIcon.size;
  static const double _kActionGap = 6;
  static const double _kEmojiPickerHeight = 280;

  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _leadingActionsKey = GlobalKey();
  final GlobalKey _inputFieldKey = GlobalKey();
  bool _isInputFocused = false;
  bool _showLeftActions = false;

  TempChatController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onInputFocusChanged);
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_onInputFocusChanged);
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onInputFocusChanged() {
    if (!mounted) return;
    final nextFocused = _inputFocusNode.hasFocus;
    if (_isInputFocused == nextFocused && !_showLeftActions) return;

    setState(() {
      _isInputFocused = nextFocused;
      _showLeftActions = false;
    });
  }

  void _collapseLeftActions() {
    if (!_showLeftActions) return;
    setState(() => _showLeftActions = false);
  }

  void _toggleLeftActions() {
    if (!_isInputFocused) return;
    setState(() => _showLeftActions = !_showLeftActions);
  }

  double _leadingWidth() {
    if (!_isInputFocused) {
      return (_kActionSize * 2) + (_kActionGap * 2);
    }
    if (_showLeftActions) {
      return (_kActionSize * 2) + (_kActionGap * 2);
    }
    return _kActionSize + _kActionGap;
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

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _insertEmoji(String emoji) {
    final inputController = controller.inputController;
    final text = inputController.text;
    final selection = inputController.selection;
    final textLength = text.length;
    final hasValidSelection = selection.start >= 0 && selection.end >= 0;

    final start =
        hasValidSelection
            ? _clampInt(selection.start, 0, textLength)
            : textLength;
    final end =
        hasValidSelection ? _clampInt(selection.end, start, textLength) : start;

    final updatedText = text.replaceRange(start, end, emoji);
    inputController.value = inputController.value.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
      composing: TextRange.empty,
    );

    controller.onTypingChanged(updatedText);
  }

  Widget _buildLeaveAction(BuildContext context, ThemeData theme) {
    return ActionIcon(
      onTap: () => _confirmLeave(context),
      child: Icon(
        Iconsax.close_circle,
        color:
            theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        size: 32,
      ),
    );
  }

  Widget _buildGameAction(
    BuildContext context,
    ThemeData theme,
    ColorScheme color,
  ) {
    return Obx(() {
      final canInvite = controller.canInviteWordChain;

      return ActionIcon(
        onTap: () {
          if (!canInvite) return;
          HapticFeedback.lightImpact();
          _showGameSheet(context);
        },
        backgroundColor:
            canInvite
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
        child: Icon(
          Iconsax.game,
          color:
              canInvite
                  ? color.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          size: 32,
        ),
      );
    });
  }

  Widget _buildToggleAction() {
    return ActionIcon(
      onTap: _toggleLeftActions,
      child: const Icon(Icons.menu_rounded, size: 28),
    );
  }

  Widget _buildLeadingContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme color,
  ) {
    if (!_isInputFocused) {
      return OverflowBox(
        key: const ValueKey("leading_idle"),
        alignment: Alignment.centerLeft,
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: _kActionSize,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLeaveAction(context, theme),
            const SizedBox(width: _kActionGap),
            _buildGameAction(context, theme, color),
            const SizedBox(width: _kActionGap),
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
        maxHeight: _kActionSize,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_buildToggleAction(), const SizedBox(width: _kActionGap)],
        ),
      );
    }

    return OverflowBox(
      key: const ValueKey("leading_expanded"),
      alignment: Alignment.centerLeft,
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: _kActionSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLeaveAction(context, theme),
          const SizedBox(width: _kActionGap),
          _buildGameAction(context, theme, color),
          const SizedBox(width: _kActionGap),
        ],
      ),
    );
  }

  Widget _buildLeadingActions(
    BuildContext context,
    ThemeData theme,
    ColorScheme color,
  ) {
    return AnimatedContainer(
      duration: _kLeadingAnimDuration,
      curve: Curves.easeOutCubic,
      width: _leadingWidth(),
      height: _kActionSize,
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
          child: _buildLeadingContent(context, theme, color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return SafeArea(
      child: Obx(() {
        final isTyping = controller.isTyping.value;
        final liked = controller.userLiked.value;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onBottomBarPointerDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TelepathyInviteBar(controller: controller),
              WordChainInviteBar(controller: controller),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Obx(() {
                  final reply = controller.replyingMessage.value;
                  if (reply == null) return const SizedBox();

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
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
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: controller.cancelReply,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 18),
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
                  KeyedSubtree(
                    key: _leadingActionsKey,
                    child: _buildLeadingActions(context, theme, color),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      key: _inputFieldKey,
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: controller.inputController,
                        focusNode: _inputFocusNode,
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
                          prefixIcon: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              FocusScope.of(context).unfocus();
                              controller.toggleEmoji();
                            },
                            child: const Icon(Iconsax.emoji_happy, size: 22),
                          ),
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) {
                      return ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.9,
                          end: 1.0,
                        ).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      );
                    },
                    child:
                        isTyping
                            ? ActionIcon(
                              key: const ValueKey("send"),
                              onTap: () {
                                final text =
                                    controller.inputController.text.trim();
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
                            : ActionIcon(
                              key: const ValueKey("like"),
                              onTap: () {
                                if (liked == true) return;
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
                                        ? Iconsax.lovely5
                                        : Iconsax.lovely,
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
                  child:
                      controller.showEmoji.value
                          ? SizedBox(
                            height: _kEmojiPickerHeight,
                            width: MediaQuery.of(context).size.width,
                            child: EmojiPicker(
                              onEmojiSelected: (_, emoji) {
                                _insertEmoji(emoji.emoji);
                              },
                              config: Config(
                                height: _kEmojiPickerHeight,
                                emojiViewConfig: EmojiViewConfig(
                                  columns: 8,
                                  emojiSizeMax: 28,
                                  backgroundColor: scheme.surface,
                                ),
                                categoryViewConfig: CategoryViewConfig(
                                  backgroundColor: scheme.surface,
                                  indicatorColor: scheme.primary,
                                  iconColor: scheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
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

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Thoát phòng"),
        content: const Text("Bạn có chắc muốn thoát phòng không?"),
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

  void _showGameSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Chọn trò chơi",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                GameSheetItem(
                  imageAsset: "assets/games/word_chain.png",
                  title: "Nối từ",
                  subtitle: "Luân phiên nối 2 từ, sai là chịu phạt",
                  onTap: () {
                    Get.back();
                    controller.inviteWordChainManual();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
