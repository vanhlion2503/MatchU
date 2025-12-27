import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/utils/presence_utils.dart';
import 'package:matchu_app/widgets/online_dot_pulse.dart';


Widget chatItem({
  required BuildContext context,
  required ChatRoomModel room,
  required String myUid,
  required VoidCallback onTap,
}) {
  final isMe = room.lastSenderId == myUid;
  final unread = room.unreadCount(myUid);

  final otherUid = room.participants.firstWhere((e) => e != myUid);
  final userCache = Get.find<ChatUserCacheController>();

  userCache.loadIfNeeded(otherUid);

  return Obx((){
    final otherUser = userCache.getUser(otherUid);
    final online = otherUser != null && isUserOnline(otherUser.lastActiveAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: 
                    otherUser != null && otherUser.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(otherUser.avatarUrl) : null,
                  child: otherUser == null || otherUser.avatarUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: OnlineDotPulse(
                    online: online,
                    size: 10,
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
                  Text(
                    otherUser?.fullname ?? "Đang tải ...",
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMe ? "Bạn: ${room.lastMessage}" : room.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
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
                      ?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
    );
  });
}

String formatChatTime(DateTime? time) {
  if (time == null) return "";
  return DateFormat('HH:mm').format(time);
}
