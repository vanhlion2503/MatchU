import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/list_chat/confirm_delete_chat.dart';
import 'package:matchu_app/views/chat/list_chat/swipe_chat_item.dart';
import 'package:matchu_app/views/chat/list_chat/ui_item_chat.dart';


class ChatListView extends StatelessWidget {
  ChatListView({super.key});

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChatListController());
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
                final isSearching = controller.searchText.isNotEmpty;
                final rooms = controller.filteredRooms;

                if (rooms.isEmpty) {
                  return Center(
                    child: Text(
                      isSearching
                          ? "Không tìm thấy kết quả"
                          : "Chưa có cuộc trò chuyện",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                /// 🔍 ĐANG SEARCH → ListView (AN TOÀN)
                if (isSearching) {
                  return ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return SwipeChatItem(
                        room: room,
                        uid: myUid,
                        onPin: () => controller.pin(room),
                        onDelete: () {
                          showConfirmDeleteChat(
                            onConfirm: () => controller.delete(room),
                          );
                        },
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

                /// 🔥 KHÔNG SEARCH → AnimatedList (REORDER MƯỢT)
                return AnimatedList(
                  key: _listKey,
                  initialItemCount: rooms.length,
                  itemBuilder: (context, index, animation) {
                    final room = rooms[index];
                    return SizeTransition(
                      sizeFactor: animation,
                      child: SwipeChatItem(
                        room: room,
                        uid: myUid,
                        onPin: () => controller.pin(room),
                        onDelete: () {
                          showConfirmDeleteChat(
                            onConfirm: () => controller.delete(room),
                          );
                        },
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
              }),
            ),

          ],
        ),
      ),
    );
  }
}
