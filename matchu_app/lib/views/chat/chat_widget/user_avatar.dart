import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';

class UserAvatar extends StatelessWidget {
  final String userId;
  final double radius;

  const UserAvatar({super.key, required this.userId, this.radius = 16});

  static const String _fallbackAsset = 'assets/avatas/avataMd.png';

  @override
  Widget build(BuildContext context) {
    final cache = Get.find<ChatUserCacheController>();
    unawaited(cache.loadIfNeeded(userId));

    return Obx(() {
      cache.version.value;

      final user = cache.getUser(userId);
      final avatarUrl = user?.avatarUrl ?? "";
      final size = radius * 2;

      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child:
              avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, __) => _fallbackImage(size),
                    errorWidget: (_, __, ___) => _fallbackImage(size),
                  )
                  : _fallbackImage(size),
        ),
      );
    });
  }

  Widget _fallbackImage(double size) {
    return Image.asset(
      _fallbackAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
