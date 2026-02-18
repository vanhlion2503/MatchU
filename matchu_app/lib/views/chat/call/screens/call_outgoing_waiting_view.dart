import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';

class CallOutgoingWaitingView extends GetView<CallController> {
  const CallOutgoingWaitingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = controller.peerAvatarUrl.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          Positioned.fill(
            child:
                avatarUrl.isNotEmpty
                    ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) =>
                                const ColoredBox(color: Color(0xFF0D1117)),
                      ),
                    )
                    : const ColoredBox(color: Color(0xFF0D1117)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RippleAnimation(
                      color: Colors.white.withValues(alpha: 0.22),
                      minRadius: 40,
                      ripplesCount: 2,
                      duration: const Duration(seconds: 3),
                      repeat: true,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme.darkBorder,
                          backgroundImage:
                              avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                          child:
                              avatarUrl.isEmpty
                                  ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white70,
                                  )
                                  : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      controller.peerName.value,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đang gọi ...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
