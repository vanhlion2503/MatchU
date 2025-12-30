import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/utils/presence_utils.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/views/chat/long_chat/chat_body.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final roomId = Get.arguments["roomId"] as String;

    final ChatController controller = Get.put(ChatController(roomId), tag: roomId);
    final userCache = Get.find<ChatUserCacheController>();
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 60,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface.withOpacity(0.95),

        /// ================= LEADING (RIÊNG) =================
        leading: GestureDetector(
          onTap: () => Get.back(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.arrow_back_ios_new, // 👈 icon bạn chọn
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        titleSpacing: 0, 
        /// ================= TITLE (AVATAR + TÊN = 1 BỘ) =================
        title: Obx(() {
          final otherUid = controller.otherUid.value;
          if (otherUid == null) {
            return const Text("Đang tải...");
          }

          final userCache = Get.find<ChatUserCacheController>();
          final presence = Get.find<PresenceController>();

          final otherUser = userCache.getUser(otherUid);
          final online = presence.isOnline(otherUid);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Get.to(
                () => OtherProfileView(userId: otherUid),
                transition: Transition.cupertino,
              );
            },
            child: Row(
              children: [
                /// ===== AVATAR =====
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundImage: otherUser != null &&
                              otherUser.avatarUrl.isNotEmpty
                          ? NetworkImage(otherUser.avatarUrl)
                          : null,
                      child: otherUser == null ||
                              otherUser.avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online ? Colors.green : Colors.grey,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 10),

                /// ===== NAME + STATUS =====
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        otherUser?.fullname ?? "Người dùng",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        online
                            ? "Đang hoạt động"
                            : formatLastActive(otherUser?.lastActiveAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),


        actions: [
          IconButton(
            icon: const Icon(
              Iconsax.more_circle,
              size: 32,
              ),
            onPressed: () {
              debugPrint("More");
            },
          ),
        ],

        /// ================= DIVIDER =================
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: theme.dividerColor.withOpacity(0.4),
          ),
        ),
      ),

      /// ================= BODY =================
      body: SafeArea(
        child: ChatBody(controller: controller),
      ),
    );
  }
}
