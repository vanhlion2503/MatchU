import 'package:flutter/material.dart';

class AnonymousAvatar extends StatelessWidget {
  final String? avatarKey; // 👈 avt_01, avt_02...
  final double radius;

  const AnonymousAvatar({
    super.key,
    required this.avatarKey,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          Theme.of(context).colorScheme.surfaceVariant,
      backgroundImage: avatarKey == null
          ? const AssetImage(
              "assets/anonymous/placeholder.png",
            )
          : AssetImage(
              "assets/anonymous/$avatarKey.png",
            ),
    );
  }
}
