import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class CallAudioLayer extends StatelessWidget {
  const CallAudioLayer({super.key, required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF111827)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 62,
              backgroundColor: AppTheme.darkBorder,
              backgroundImage:
                  controller.peerAvatarUrl.value.isNotEmpty
                      ? NetworkImage(controller.peerAvatarUrl.value)
                      : null,
              child:
                  controller.peerAvatarUrl.value.isEmpty
                      ? const Icon(
                        Icons.person,
                        size: 58,
                        color: Colors.white70,
                      )
                      : null,
            ),
            const SizedBox(height: 20),
            Text(
              controller.peerName.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
