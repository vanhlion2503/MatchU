import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/matching/video_matching_controller.dart';
import 'package:matchu_app/translations/localized_material.dart';

class VideoSearchingStage extends StatefulWidget {
  const VideoSearchingStage({super.key, required this.controller});

  final VideoMatchingController controller;

  @override
  State<VideoSearchingStage> createState() => _VideoSearchingStageState();
}

class _VideoSearchingStageState extends State<VideoSearchingStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = widget.controller;
      final preparing =
          controller.phase.value == VideoMatchingPhase.preparing ||
          !controller.previewReady.value;

      return ColoredBox(
        color: const Color(0xFF090A12),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _SelfPreview(
                    controller: controller,
                    preparing: preparing,
                  ),
                ),
                Container(height: 1, color: Colors.white12),
                Expanded(
                  child: _DiscoveryField(
                    animation: _motionController,
                    elapsed: controller.formattedSearchTime,
                    preparing: preparing,
                  ),
                ),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _RoundAction(
                    tooltip: 'Hủy tìm kiếm'.tr,
                    icon: Icons.close_rounded,
                    onTap: () => controller.cancelSearch(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SelfPreview extends StatelessWidget {
  const _SelfPreview({required this.controller, required this.preparing});

  final VideoMatchingController controller;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!preparing)
          RTCVideoView(
            controller.localRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
        else
          const ColoredBox(color: Color(0xFF171925)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.34),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        if (preparing)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Đang chuẩn bị camera...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        Positioned(
          left: 18,
          right: 72,
          bottom: 18,
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Camera xem trước chỉ hiển thị trên thiết bị của bạn.',
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoveryField extends StatelessWidget {
  const _DiscoveryField({
    required this.animation,
    required this.elapsed,
    required this.preparing,
  });

  final Animation<double> animation;
  final String elapsed;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF15142A),
                  Color(0xFF261448),
                  Color(0xFF0E172A),
                ],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size.square(260),
                  painter: _PulsePainter(animation.value),
                );
              },
            ),
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 0.0,
            alignment: const Alignment(-0.82, -0.48),
            asset: 'assets/anonymous/avt_04.png',
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 1.7,
            alignment: const Alignment(0.78, -0.58),
            asset: 'assets/anonymous/avt_12.png',
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 3.1,
            alignment: const Alignment(-0.68, 0.68),
            asset: 'assets/anonymous/avt_18.png',
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 4.2,
            alignment: const Alignment(0.72, 0.62),
            asset: 'assets/anonymous/avt_23.png',
          ),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.42),
                    blurRadius: 34,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Iconsax.radar_1, color: Colors.white, size: 38),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Column(
              children: [
                Text(
                  preparing
                      ? 'Đang chuẩn bị camera...'
                      : 'Đang tìm vibe phù hợp',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  elapsed,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 15,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBlurCard extends StatelessWidget {
  const _FloatingBlurCard({
    required this.animation,
    required this.phase,
    required this.alignment,
    required this.asset,
  });

  final Animation<double> animation;
  final double phase;
  final Alignment alignment;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final angle = (animation.value * math.pi * 2) + phase;
          return Transform.translate(
            offset: Offset(math.sin(angle) * 9, math.cos(angle) * 7),
            child: Transform.rotate(
              angle: math.sin(angle) * 0.045,
              child: child,
            ),
          );
        },
        child: Opacity(
          opacity: 0.38,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Container(
              width: 58,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(asset, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var index = 0; index < 4; index++) {
      final wave = (progress + (index / 4)) % 1;
      final radius = 38 + (wave * 92);
      final opacity = (1 - wave) * 0.28;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFB794F4).withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.38),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () => onTap(),
          icon: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
