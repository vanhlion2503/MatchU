import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/utils/highlight_text.dart';

Widget chatItem({
  required BuildContext context,
  required ChatRoomModel room,
  required String myUid,
  required String searchQuery,
  required VoidCallback onTap,
}) {
  final isMe = room.lastSenderId == myUid;
  final unread = room.unreadCount(myUid);

  final otherUid = room.participants.firstWhere((e) => e != myUid);
  final userCache = Get.find<ChatUserCacheController>();

  userCache.loadIfNeeded(otherUid);

    return Obx(() {
    // 🔥 BẮT BUỘC đọc RxMap để Obx biết cần rebuild
    userCache.version.value;

    final otherUser = userCache.getUser(otherUid);
    final presence = Get.find<PresenceController>();

    presence.listen(otherUid);

    final online = presence.isOnline(otherUid);


    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: otherUser != null &&
                                otherUser.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(otherUser.avatarUrl)
                            : null,
                        child: otherUser == null ||
                                otherUser.avatarUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online ? Colors.green : Colors.grey,
                            border: Border.all(
                              color: Theme.of(context)
                                  .scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      
                  const SizedBox(width: 12),
      
                  /// NAME + MESSAGE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: highlightText(
                            text: otherUser?.fullname ?? "",
                            query: searchQuery,
                            normalStyle: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(fontWeight: FontWeight.w600),
                            highlightStyle: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: highlightText(
                            text: isMe
                                ? "Bạn: ${room.lastMessage}"
                                : room.lastMessage,
                            query: searchQuery,
                            normalStyle:
                                Theme.of(context).textTheme.bodyMedium!,
                            highlightStyle: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
      
                  const SizedBox(width: 8),
      
                  /// TIME + UNREAD
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatChatTime(room.lastMessageAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
      
            if (room.isPinned(myUid))
              Positioned(
                top: 6,
                right: 12,
                child: Icon(
                  Icons.push_pin,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  });

}

String formatChatTime(DateTime? time) {
  if (time == null) return "";
  return DateFormat('HH:mm').format(time);
}
