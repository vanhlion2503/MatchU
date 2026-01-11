import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/list_chat/confirm_delete_chat.dart';
import 'package:matchu_app/views/chat/list_chat/passcode_prompt_dialog.dart';
import 'package:matchu_app/views/chat/list_chat/shimmer/chat_list_shimmer.dart';
import 'package:matchu_app/views/chat/list_chat/swipe_chat_item.dart';
import 'package:matchu_app/views/chat/list_chat/ui_item_chat.dart';


class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late final ChatListController controller;
  bool _passcodeChecked = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ChatListController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePasscodeFlow();
    });
  }

  Future<void> _ensurePasscodeFlow() async {
    if (_passcodeChecked) return;
    _passcodeChecked = true;

    final historyLocked = await PasscodeBackupService.isHistoryLocked();
    if (historyLocked) return;

    final hasLocal = await PasscodeBackupService.hasLocalBackupKey();
    if (hasLocal) return;

    final hasBackup = await PasscodeBackupService.hasBackupOnServer();
    if (!mounted) return;

    if (!hasBackup) {
      final passcode = await showPasscodeSetupDialog(context);
      if (passcode == null || passcode.isEmpty) return;
      await PasscodeBackupService.setPasscode(passcode);
      return;
    }

    String? errorText;
    while (mounted) {
      final result = await showPasscodeUnlockDialog(
        context,
        errorText: errorText,
      );

      if (result == null) return;

      if (result.action == PasscodePromptAction.skipped) {
        await PasscodeBackupService.setHistoryLocked(true);
        return;
      }

      if (result.action == PasscodePromptAction.reset) {
        final confirm = await showPasscodeResetConfirmDialog(context);
        if (!confirm) return;

        await PasscodeBackupService.resetPasscode();
        controller.clearPreviewCache();

        final newPasscode = await showPasscodeSetupDialog(context);
        if (newPasscode == null || newPasscode.isEmpty) return;
        await PasscodeBackupService.setPasscode(
          newPasscode,
          lockHistory: true,
        );
        return;
      }

      final passcode = result.passcode ?? '';
      final unlocked = await PasscodeBackupService.unlockPasscode(passcode);
      if (!unlocked) {
        errorText = 'Mã pin không đúng';
        continue;
      }

      final restoredRooms = await PasscodeBackupService.restoreAllSessionKeys();
      for (final roomId in restoredRooms) {
        SessionKeyService.notifyUpdated(roomId);
      }
      if (restoredRooms.isNotEmpty) {
        await controller.refreshLastMessagePreviews();
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userC = Get.find<UserController>();
    final theme = Theme.of(context);
    final myUid = ChatService().uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 14),
            Obx((){
              final avatarU = userC.avatarUrl;
              return Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    backgroundImage: avatarU.isNotEmpty ? CachedNetworkImageProvider(avatarU) : null,
                    child: avatarU.isEmpty
                      ? const Icon(Icons.person, size: 18)
                      : null,
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkBorder 
                          : AppTheme.lightBorder,
                          width: 1.5, 
                        ),
                      ),
                    ),
                  )
                ],
              );
            }),
            const SizedBox(width: 14),
            /// 📨 TITLE
            Expanded(
              child: Text(
                "Tin nhắn",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            /// ❌ NÚT THOÁT
            IconButton(
              icon: const Icon(
                Iconsax.logout_1,
                size: 32,
                ),
              onPressed: () {
                Get.back();
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Obx(() {
                final hasText = controller.searchText.isNotEmpty;

                return TextField(
                  controller: controller.textController,
                  focusNode: controller.focusNode,
                  onChanged: (v) {
                    controller.searchText.value = v;

                    if (v.isEmpty) {
                      controller.focusNode.unfocus();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "Tìm kiếm cuộc trò chuyện",
                    prefixIcon: const Icon(Iconsax.search_normal_1),

                    /// ❌ CLEAR BUTTON
                    suffixIcon: hasText
                      ? IconButton(
                          icon: const Icon(Iconsax.close_circle),
                          onPressed: controller.clearSearch,
                        )
                      : null,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,

                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.98,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },

                  child: controller.isLoading.value
                      ? const ChatListShimmer(
                          key: ValueKey("shimmer"),
                        )
                      : _buildChatList(
                          key: const ValueKey("list"),
                          controller: controller,
                          myUid: myUid,
                          listKey: _listKey,
                        ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildChatList({
  required ChatListController controller,
  required String myUid,
  required GlobalKey<AnimatedListState> listKey,
  Key? key,
}) {
  final isSearching = controller.searchText.isNotEmpty;
  final rooms = controller.filteredRooms;

  if (rooms.isEmpty) {
    return Center(
      key: key,
      child: Text(
        isSearching
            ? "Không tìm thấy kết quả"
            : "Chưa có cuộc trò chuyện",
      ),
    );
  }

  if (isSearching) {
    return ListView.builder(
      key: key,
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return SwipeChatItemMessage(
          onPin: () => controller.pin(room),
          onDelete: () => showConfirmDeleteChat(
            onConfirm: () => controller.delete(room),
          ),
          onMore: () {},
          child: chatItem(
            context: context,
            room: room,
            myUid: myUid,
            searchQuery: controller.searchText.value,
            onTap: () async {
              await ChatService().markAsRead(room.id);
              Get.toNamed(
                AppRouter.chat,
                arguments: {"roomId": room.id},
              );
            },
          ),
        );
      },
    );
  }

  return AnimatedList(
    key: listKey,
    initialItemCount: rooms.length,
    itemBuilder: (context, index, animation) {
      final room = rooms[index];
      return SizeTransition(
        sizeFactor: animation,
        child: SwipeChatItemMessage(
          onPin: () => controller.pin(room),
          onDelete: () => showConfirmDeleteChat(
            onConfirm: () => controller.delete(room),
          ),
          onMore: () {},
          child: chatItem(
            context: context,
            room: room,
            myUid: myUid,
            searchQuery: controller.searchText.value,
            onTap: () async {
              await ChatService().markAsRead(room.id);
              Get.toNamed(
                AppRouter.chat,
                arguments: {"roomId": room.id},
              );
            },
          ),
        ),
      );
    },
  );
}

