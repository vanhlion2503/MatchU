import 'dart:ui';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/matching/video_matching_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/translations/localized_material.dart';

class VideoSearchingStage extends StatefulWidget {
  const VideoSearchingStage({super.key, required this.controller});

  final VideoMatchingController controller;

  @override
  State<VideoSearchingStage> createState() => _VideoSearchingStageState();
}

class _VideoSearchingStageState extends State<VideoSearchingStage>
    with TickerProviderStateMixin {
  late final AnimationController _motionController;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return ColoredBox(
      color: const Color(0xFF090A12),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Obx(() {
                  final preparing =
                      controller.phase.value == VideoMatchingPhase.preparing ||
                      !controller.previewReady.value;
                  return _SelfPreview(
                    controller: controller,
                    preparing: preparing,
                    scanAnimation: _scanController,
                  );
                }),
              ),
              Container(height: 1, color: Colors.white12),
              Expanded(
                child: _DiscoveryField(
                  animation: _motionController,
                  controller: controller,
                ),
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _SearchingHeader(animation: _motionController),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 14),
                child: _HomeActionButton(onTap: controller.minimizeSearch),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfPreview extends StatelessWidget {
  const _SelfPreview({
    required this.controller,
    required this.preparing,
    required this.scanAnimation,
  });

  final VideoMatchingController controller;
  final bool preparing;
  final Animation<double> scanAnimation;

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
          _BlurredAnonymousPreview(
            avatarAsset: 'assets/anonymous/${controller.anonymousAvatar}.png',
          ),
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
        // The scan remains visible after the preview is ready to reinforce the
        // active matching state without touching the WebRTC camera lifecycle.
        _CameraScanOverlay(animation: scanAnimation),
        Positioned(
          left: 14,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Bạn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurredAnonymousPreview extends StatelessWidget {
  const _BlurredAnonymousPreview({required this.avatarAsset});

  final String avatarAsset;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.1,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.asset(
                avatarAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: 720,
              ),
            ),
          ),
          ColoredBox(color: const Color(0xFF111320).withValues(alpha: 0.42)),
        ],
      ),
    );
  }
}

class _CameraScanOverlay extends StatelessWidget {
  const _CameraScanOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const beamHeight = 52.0;
        final travel = constraints.maxHeight + beamHeight;

        return IgnorePointer(
          child: ClipRect(
            child: AnimatedBuilder(
              animation: animation,
              child: const RepaintBoundary(child: _CameraScanBeam()),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (travel * animation.value) - beamHeight),
                  child: Align(alignment: Alignment.topCenter, child: child),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _CameraScanBeam extends StatelessWidget {
  const _CameraScanBeam();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x246FE6FC)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xCC6FE6FC),
                    Colors.white,
                    Color(0xCC6FE6FC),
                    Colors.transparent,
                  ],
                  stops: [0, 0.16, 0.5, 0.84, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.58),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryField extends StatelessWidget {
  const _DiscoveryField({required this.animation, required this.controller});

  final Animation<double> animation;
  final VideoMatchingController controller;

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
                  Color(0xFF071521),
                  Color(0xFF0B2A3D),
                  Color(0xFF08121F),
                ],
              ),
            ),
          ),
          const _FloatingProfileBackdrop(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.18),
                radius: 1.08,
                colors: [Color(0x18071521), Color(0xA607111C)],
                stops: [0.18, 1],
              ),
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: RepaintBoundary(
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
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.48),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.radar_1,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: Column(
              children: [
                const Text(
                  'Đang tìm kiếm...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Obx(
                  () => Text(
                    controller.formattedSearchTime,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _CancelSearchButton(onTap: controller.cancelSearch),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingProfileBackdrop extends StatefulWidget {
  const _FloatingProfileBackdrop();

  @override
  State<_FloatingProfileBackdrop> createState() =>
      _FloatingProfileBackdropState();
}

class _FloatingProfileBackdropState extends State<_FloatingProfileBackdrop>
    with TickerProviderStateMixin {
  static const _cards = <_FloatingProfileCardSpec>[
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_02.png',
      alignment: Alignment(-1.08, -0.72),
      width: 62,
      height: 86,
      blur: 14,
      opacity: 0.13,
      scale: 0.87,
      rotationDegrees: -1.8,
      driftX: 5,
      driftY: 12,
      duration: Duration(milliseconds: 7200),
      phase: 0.12,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_07.png',
      alignment: Alignment(1.04, -0.7),
      width: 70,
      height: 96,
      blur: 12,
      opacity: 0.16,
      scale: 0.92,
      rotationDegrees: 1.6,
      driftX: -7,
      driftY: 10,
      duration: Duration(milliseconds: 5800),
      phase: 0.64,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_11.png',
      alignment: Alignment(-0.78, -0.02),
      width: 78,
      height: 106,
      blur: 8,
      opacity: 0.22,
      scale: 1,
      rotationDegrees: -1.2,
      driftX: 8,
      driftY: 14,
      duration: Duration(milliseconds: 4600),
      phase: 0.38,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_15.png',
      alignment: Alignment(0.04, -0.3),
      width: 92,
      height: 122,
      blur: 6,
      opacity: 0.28,
      scale: 1.08,
      rotationDegrees: 0.8,
      driftX: -5,
      driftY: 9,
      duration: Duration(milliseconds: 6400),
      phase: 0.82,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_19.png',
      alignment: Alignment(0.84, 0.04),
      width: 80,
      height: 110,
      blur: 8,
      opacity: 0.22,
      scale: 1.02,
      rotationDegrees: 1.4,
      driftX: 7,
      driftY: 13,
      duration: Duration(milliseconds: 5200),
      phase: 0.24,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_22.png',
      alignment: Alignment(-1.1, 0.74),
      width: 64,
      height: 90,
      blur: 13,
      opacity: 0.12,
      scale: 0.89,
      rotationDegrees: 1.9,
      driftX: -6,
      driftY: 15,
      duration: Duration(milliseconds: 7800),
      phase: 0.52,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_24.png',
      alignment: Alignment(1.08, 0.72),
      width: 68,
      height: 94,
      blur: 11,
      opacity: 0.15,
      scale: 0.93,
      rotationDegrees: -1.7,
      driftX: 9,
      driftY: 11,
      duration: Duration(milliseconds: 6900),
      phase: 0.7,
    ),
  ];

  late final List<AnimationController> _controllers;
  late final List<CurvedAnimation> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final card in _cards)
        AnimationController(vsync: this, duration: card.duration)
          ..value = card.phase
          ..repeat(reverse: true),
    ];
    _animations = [
      for (final controller in _controllers)
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
          reverseCurve: Curves.easeInOut,
        ),
    ];
  }

  @override
  void dispose() {
    for (final animation in _animations) {
      animation.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < _cards.length; index++)
            _AnimatedFloatingProfileCard(
              spec: _cards[index],
              animation: _animations[index],
            ),
        ],
      ),
    );
  }
}

class _AnimatedFloatingProfileCard extends StatelessWidget {
  const _AnimatedFloatingProfileCard({
    required this.spec,
    required this.animation,
  });

  final _FloatingProfileCardSpec spec;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final opacityAnimation = Tween<double>(
      begin: spec.opacity * 0.86,
      end: spec.opacity,
    ).animate(animation);
    final positionAnimation = Tween<Offset>(
      begin: Offset(-spec.driftX / spec.width, -spec.driftY / spec.height),
      end: Offset(spec.driftX / spec.width, spec.driftY / spec.height),
    ).animate(animation);
    final rotationAnimation = Tween<double>(
      begin: (spec.rotationDegrees - 0.1) / 360,
      end: (spec.rotationDegrees + 0.1) / 360,
    ).animate(animation);
    final scaleAnimation = Tween<double>(
      begin: spec.scale * 0.985,
      end: spec.scale * 1.015,
    ).animate(animation);

    return Align(
      alignment: spec.alignment,
      child: FadeTransition(
        opacity: opacityAnimation,
        child: SlideTransition(
          position: positionAnimation,
          child: RotationTransition(
            turns: rotationAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: RepaintBoundary(
                child: SizedBox(
                  width: spec.width,
                  height: spec.height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: spec.blur,
                        sigmaY: spec.blur,
                      ),
                      child: Image.asset(
                        spec.asset,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        cacheWidth: 220,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingProfileCardSpec {
  const _FloatingProfileCardSpec({
    required this.asset,
    required this.alignment,
    required this.width,
    required this.height,
    required this.blur,
    required this.opacity,
    required this.scale,
    required this.rotationDegrees,
    required this.driftX,
    required this.driftY,
    required this.duration,
    required this.phase,
  });

  final String asset;
  final Alignment alignment;
  final double width;
  final double height;
  final double blur;
  final double opacity;
  final double scale;
  final double rotationDegrees;
  final double driftX;
  final double driftY;
  final Duration duration;
  final double phase;
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
          ..color = AppTheme.secondaryColor.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SearchingHeader extends StatelessWidget {
  const _SearchingHeader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.88,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(animation);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF071521).withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: pulseAnimation,
            child: RepaintBoundary(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.7),
                      blurRadius: 9,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Đang tìm bạn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelSearchButton extends StatelessWidget {
  const _CancelSearchButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.72),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
          shape: const StadiumBorder(),
        ),
        onPressed: () => onTap(),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Hủy tìm kiếm',
            maxLines: 1,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Thu nhỏ tìm kiếm'.tr,
      child: Material(
        color: const Color(0xFF071521).withValues(alpha: 0.42),
        shape: CircleBorder(
          side: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.32),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onTap(),
          child: const SizedBox.square(
            dimension: 44,
            child: Icon(Iconsax.home_2, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}
