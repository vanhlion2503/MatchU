import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/list_chat/confirm_delete_chat.dart';
import 'package:matchu_app/views/chat/list_chat/passcode_prompt_dialog.dart';
import 'package:matchu_app/views/chat/list_chat/shimmer/chat_list_shimmer.dart';
import 'package:matchu_app/views/chat/list_chat/swipe_chat_item.dart';
import 'package:matchu_app/views/chat/list_chat/ui_item_chat.dart';

const _chatListMainTabIndex = 3;

class ChatListView extends StatefulWidget {
  final bool embedInMainNavigation;

  const ChatListView({super.key, this.embedInMainNavigation = false});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView>
    with WidgetsBindingObserver {
  late final ChatListController controller;
  Worker? _mainTabWorker;
  bool _passcodeFlowRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller =
        Get.isRegistered<ChatListController>()
            ? Get.find<ChatListController>()
            : Get.put(ChatListController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePasscodeFlowIfVisible();
    });

    if (widget.embedInMainNavigation && Get.isRegistered<MainController>()) {
      final mainController = Get.find<MainController>();
      _mainTabWorker = ever<int>(mainController.currentIndex, (index) {
        if (index == _chatListMainTabIndex) {
          _ensurePasscodeFlowIfVisible();
        }
      });
    }

    if (!widget.embedInMainNavigation &&
        Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().enterChatList();
    }
  }

  bool get _isVisibleForPasscode {
    if (!mounted) return false;
    if (!widget.embedInMainNavigation) return true;
    if (!Get.isRegistered<MainController>()) return false;

    return Get.find<MainController>().currentIndex.value ==
        _chatListMainTabIndex;
  }

  Future<void> _ensurePasscodeFlowIfVisible() async {
    if (!_isVisibleForPasscode || _passcodeFlowRunning) return;
    _passcodeFlowRunning = true;

    try {
      await ensurePasscodeReady(
        context,
        shouldContinue: () => _isVisibleForPasscode,
        onPasscodeReset: () async => controller.clearPreviewCache(),
        onUnlocked: controller.refreshLastMessagePreviews,
      );
    } finally {
      _passcodeFlowRunning = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensurePasscodeFlowIfVisible();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainTabWorker?.dispose();
    if (!widget.embedInMainNavigation &&
        Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().leaveChatList();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userC = Get.find<UserController>();
    final theme = Theme.of(context);
    final myUid = ChatService().uid;
    final bottomListPadding = widget.embedInMainNavigation ? 108.0 : 12.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 14),
            Obx(() {
              final avatarU = userC.avatarUrl;
              return Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    backgroundImage:
                        avatarU.isNotEmpty
                            ? CachedNetworkImageProvider(avatarU)
                            : null,
                    child:
                        avatarU.isEmpty
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
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
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
            if (!widget.embedInMainNavigation) ...[
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 28),
                onPressed: Get.back,
              ),
              const SizedBox(width: 4),
            ],
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
                    suffixIcon:
                        hasText
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

                  child:
                      controller.isLoading.value
                          ? const ChatListShimmer(key: ValueKey("shimmer"))
                          : _buildChatList(
                            key: const ValueKey("list"),
                            controller: controller,
                            myUid: myUid,
                            bottomPadding: bottomListPadding,
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
  required double bottomPadding,
  Key? key,
}) {
  final isSearching = controller.searchText.isNotEmpty;
  final rooms = controller.filteredRooms;

  if (rooms.isEmpty) {
    return Center(
      key: key,
      child: Text(
        isSearching ? "Không tìm thấy kết quả" : "Chưa có cuộc trò chuyện",
      ),
    );
  }

  if (isSearching) {
    return ListView.builder(
      key: key,
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return SwipeChatItemMessage(
          onPin: () => controller.pin(room),
          onDelete:
              () => showConfirmDeleteChat(
                onConfirm: () => controller.delete(room),
              ),
          onMore: () {},
          child: chatItem(
            context: context,
            room: room,
            myUid: myUid,
            searchQuery: controller.searchText.value,
            onTap: () async {
              await _openChatRoom(context, room, myUid);
            },
          ),
        );
      },
    );
  }

  return ListView.builder(
    key: key,
    padding: EdgeInsets.only(bottom: bottomPadding),
    itemCount: rooms.length,
    itemBuilder: (context, index) {
      if (index < 0 || index >= rooms.length) {
        return const SizedBox.shrink();
      }

      final room = rooms[index];
      return SwipeChatItemMessage(
        onPin: () => controller.pin(room),
        onDelete:
            () =>
                showConfirmDeleteChat(onConfirm: () => controller.delete(room)),
        onMore: () {},
        child: chatItem(
          context: context,
          room: room,
          myUid: myUid,
          searchQuery: controller.searchText.value,
          onTap: () async {
            await _openChatRoom(context, room, myUid);
          },
        ),
      );
    },
  );
}

Future<void> _openChatRoom(
  BuildContext context,
  ChatRoomModel room,
  String myUid,
) async {
  final otherUid = room.participants.firstWhere(
    (uid) => uid != myUid,
    orElse: () => "",
  );

  if (otherUid.isNotEmpty && Get.isRegistered<ChatUserCacheController>()) {
    final userCache = Get.find<ChatUserCacheController>();
    unawaited(userCache.loadIfNeeded(otherUid));

    final avatarUrl = userCache.getUser(otherUid)?.avatarUrl ?? "";
    if (avatarUrl.isNotEmpty) {
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(avatarUrl),
          context,
        ).catchError((_) {}),
      );
    }
  }

  await ChatService().markAsRead(room.id);

  final args = <String, dynamic>{"roomId": room.id};
  if (otherUid.isNotEmpty) {
    args["otherUid"] = otherUid;
  }

  Get.toNamed(AppRouter.chat, arguments: args);
}
