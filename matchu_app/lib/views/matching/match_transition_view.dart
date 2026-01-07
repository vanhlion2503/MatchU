import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';
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

      // ===============================
      // 1️⃣ CONVERT TEMP → PERMANENT
      // ===============================
      final newRoomId =
          await service.convertToPermanent(widget.tempRoomId);

      // ===============================
      // 2️⃣ INIT E2EE SESSION KEY
      // ===============================
      final tempSnap = await FirebaseFirestore.instance
          .collection("tempChats")
          .doc(widget.tempRoomId)
          .get();

      final participants =
          List<String>.from(tempSnap.data()!["participants"]);

      final myUid = FirebaseAuth.instance.currentUser!.uid;
      final otherUid = participants.firstWhere((e) => e != myUid);

      // 🔐 CHỈ 1 CLIENT TẠO SESSION KEY (DETERMINISTIC)
      if (myUid.compareTo(otherUid) < 0) {
        await SessionKeyService.createAndSendSessionKey(
          roomId: newRoomId,
          receiverUid: otherUid,
        );
      }


      // ===============================
      // 3️⃣ GIỮ ANIMATION MƯỢT
      // ===============================
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // ===============================
      // 4️⃣ ĐI SANG CHAT LÂU DÀI
      // ===============================
      Get.offNamed(
        "/chat",
        arguments: {
          "roomId": newRoomId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar("Lỗi", "Không thể tạo phòng chat");
      Get.back();
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
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          /// ===== BACKGROUND =====
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final maxH = constraints.maxHeight;

                final avatarSize =
                    (maxW * 0.22).clamp(60.0, 92.0);
                final avatarOffset =
                    (maxW * 0.18).clamp(40.0, 90.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: isLandscape ? 24 : 56),

                    /// ===== AVATARS =====
                    SizedBox(
                      height: avatarSize * 2,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FloatingAvatar(
                            image:
                                "assets/anonymous/${widget.myAvatar}.png",
                            offsetX: -avatarOffset,
                            delay: 0,
                            size: avatarSize,
                            badge: Iconsax.like_15,
                            badgeColor: Colors.blue,
                          ),
                          FloatingAvatar(
                            image:
                                "assets/anonymous/${widget.otherAvatar}.png",
                            offsetX: avatarOffset,
                            delay: 1,
                            size: avatarSize,
                            badge: Iconsax.heart5,
                            badgeColor: Colors.pink,
                          ),
                          const HeartRipple(),
                        ],
                      ),
                    ),

                    SizedBox(height: isLandscape ? 16 : 32),

                    /// ===== TEXT =====
                    Text(
                      "🎉 Kết nối thành công!",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Hai bạn đã thích nhau",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const Spacer(),

                    /// ===== PROGRESS CARD =====
                    Container(
                      width: maxW * 0.9,
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            color: theme.colorScheme.primary
                                .withOpacity(0.12),
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
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Đang chuyển hướng…",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.primary,
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
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.lock,
                                size: 14,
                                color: theme.colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Đang thiết lập kết nối an toàn",
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(
                                  color: theme.colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isLandscape ? 24 : 64),
                  ],
                );
              },
            ),
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
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
