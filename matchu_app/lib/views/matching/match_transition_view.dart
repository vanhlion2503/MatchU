import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import 'package:matchu_app/views/matching/widgets/animated_progress_bar.dart';
import 'package:matchu_app/views/matching/widgets/floating_avatar.dart';
import 'package:matchu_app/views/matching/widgets/heart_ripple.dart';

class MatchTransitionView extends StatefulWidget {
  final String tempRoomId;
  final String myAvatar;
  final String otherAvatar;

  const MatchTransitionView({
    super.key,
    required this.tempRoomId,
    required this.myAvatar,
    required this.otherAvatar,
  });

  @override
  State<MatchTransitionView> createState() => _MatchTransitionViewState();
}

class _MatchTransitionViewState extends State<MatchTransitionView>
    with TickerProviderStateMixin {

  late final AnimationController _bgController;
  late final AnimationController _progressController;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _startConvert();
  }

  Future<void> _startConvert() async {
    try {
      final service = TempChatService();

      final newRoomId =
          await service.convertToPermanent(widget.tempRoomId);

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Get.offNamed(
        "/chat",
        arguments: {"roomId": newRoomId},
      );
    } catch (e) {
      if (!mounted) return;

      Get.snackbar(
        "Lỗi",
        "Không thể tạo phòng chat",
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.back(); // fallback
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          /// ===== BACKGROUND MESH =====
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
              return Stack(
                children: [
                  _blurCircle(
                    alignment: Alignment(
                      -1.2 + _bgController.value * 0.2,
                      -1.1,
                    ),
                    color: Colors.blue.withOpacity(0.35),
                  ),
                  _blurCircle(
                    alignment: Alignment(
                      1.2 - _bgController.value * 0.2,
                      1.1,
                    ),
                    color: Colors.indigo.withOpacity(0.35),
                  ),
                ],
              );
            },
          ),

          /// ===== CONTENT =====
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 64),
                  Expanded(child: _avatarsSection()),
                  const SizedBox(height: 100),
                  Expanded(child: _textSection(theme)),
                  const Spacer(),
                  _progressCard(theme),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarsSection() {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [

          /// my avatar
          FloatingAvatar(
            image: "assets/anonymous/${widget.myAvatar}.png",
            offsetX: -70,
            delay: 0,
            badge: Iconsax.like_15,
            badgeColor: Colors.blue,
          ),

          /// other avatar
          FloatingAvatar(
            image: "assets/anonymous/${widget.otherAvatar}.png",
            offsetX: 70,
            delay: 1,
            badge: Iconsax.heart5,
            badgeColor: Colors.pink,
          ),
          /// heart
          const HeartRipple(),

        ],
      ),
    );
  }

  Widget _textSection(ThemeData theme) {
    return Column(
      children: [
        Text(
          "🎉 Kết nối thành công!",
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Hai bạn đã thích nhau",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _progressCard(ThemeData theme) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: theme.colorScheme.primary.withOpacity(0.12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "ĐANG TẠO PHÒNG",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Đang chuyển hướng…",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AnimatedProgressBar(
              controller: _progressController,
            ),
          ),

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.lock,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                "Đang thiết lập kết nối an toàn",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _blurCircle({
    required Alignment alignment,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
