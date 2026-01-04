import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/utils/presence_utils.dart';
import 'package:matchu_app/views/chat/long_chat/chat_body.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final roomId = Get.arguments["roomId"] as String;

    // ✅ Controller theo room (tagged)
    final ChatController controller =
        Get.put(ChatController(roomId), tag: roomId);

    // ✅ Global controllers (đã put ở main)
    final userCache = Get.find<ChatUserCacheController>();
    final presence = Get.find<PresenceController>();

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 58,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface.withOpacity(0.95),

        leading: GestureDetector(
          onTap: () => Get.back(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),

        titleSpacing: 0,
        title: Obx(() {
          final otherUid = controller.otherUid.value;
          if (otherUid == null) {
            return const Text("Đang tải...");
          }

          final otherUser = userCache.getUser(otherUid);
          final online = presence.isOnline(otherUid);

          return GestureDetector(
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
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      child: ClipOval(
                        child: FadeInImage(
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          placeholder: const AssetImage(
                              'assets/avatas/avataMd.png'),
                          image: otherUser != null &&
                                  otherUser.avatarUrl.isNotEmpty
                              ? NetworkImage(otherUser.avatarUrl)
                              : const AssetImage(
                                      'assets/avatas/avataMd.png')
                                  as ImageProvider,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
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
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        online
                            ? "Đang hoạt động"
                            : formatLastActive(otherUser?.lastActiveAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
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
            icon: const Icon(Iconsax.more, size: 30),
            onPressed: () {},
          ),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: theme.dividerColor.withOpacity(0.4),
          ),
        ),
      ),

      body: SafeArea(
        child: ChatBody(controller: controller),
      ),
    );
  }
}
