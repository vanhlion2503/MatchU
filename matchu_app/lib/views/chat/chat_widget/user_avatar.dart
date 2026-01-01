import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';

class UserAvatar extends StatelessWidget {
  final String userId;
  final double radius;

  const UserAvatar({
    super.key,
    required this.userId,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final cache = Get.find<ChatUserCacheController>();

    // đảm bảo user được load
    cache.loadIfNeeded(userId);

    return Obx(() {
      final user = cache.getUser(userId);

      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        child: ClipOval(
          child: FadeInImage(
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,

            /// 👉 ảnh mặc định luôn hiển thị trước
            placeholder:
                const AssetImage('assets/avatas/avataMd.png'),

            /// 👉 nếu có avatarUrl thì load network
            image: user != null && user.avatarUrl.isNotEmpty
                ? NetworkImage(user.avatarUrl)
                : const AssetImage('assets/avatas/avataMd.png')
                    as ImageProvider,
          ),
        ),
      );
    });
  }
}
