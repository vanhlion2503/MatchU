import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/call/widgets/call_header_info.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';

class CallOutgoingWaitingView extends StatelessWidget {
  const CallOutgoingWaitingView({
    super.key,
    required this.avatarUrl,
    required this.title,
    required this.subtitle,
  });

  final String avatarUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.38),
                  Colors.black.withValues(alpha: 0.58),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: Column(
                children: [
                  const Spacer(flex: 2),
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
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
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
                  CallHeaderInfo(title: title, subtitle: subtitle),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
