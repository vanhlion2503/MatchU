import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';

class UserAvatar extends StatelessWidget {
  final String userId;
  const UserAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    final cache = Get.find<ChatUserCacheController>();

    // đảm bảo user được load
    cache.loadIfNeeded(userId);

    return Obx(() {
      final user = cache.getUser(userId);

      if (user == null) {
        return const CircleAvatar(
          radius: 16,
          child: Icon(Icons.person, size: 14),
        );
      }

      return CircleAvatar(
        radius: 16,
        backgroundImage:
            user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
        child: user.avatarUrl.isEmpty
            ? const Icon(Icons.person, size: 14)
            : null,
      );
    });
  }
}
