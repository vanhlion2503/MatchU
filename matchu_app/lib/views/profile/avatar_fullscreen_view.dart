import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarFullscreenView extends StatelessWidget {
  final String? avatarUrl;

  const AvatarFullscreenView({
    super.key,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context), // tap để đóng
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : Image.asset(
                    "assets/avatas/avataMd.png",
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}
