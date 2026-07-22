import 'package:matchu_app/translations/localized_material.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/controllers/matching/video_matching_session_coordinator.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/widgets/animated_dots.dart';
import 'package:matchu_app/theme/app_theme.dart';

class GlobalMatchingBubble extends StatelessWidget {
  GlobalMatchingBubble({super.key});

  final controller = Get.find<MatchingController>();
  final videoCoordinator = Get.find<VideoMatchingSessionCoordinator>();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Obx(() {
      final showVideo =
          videoCoordinator.isActive.value && videoCoordinator.isMinimized.value;
      final showChat =
          controller.isMatchingActive.value &&
          !controller.isMatched.value &&
          controller.isMinimized.value;
      if (!showVideo && !showChat) {
        return const SizedBox();
      }
      final offset =
          showVideo
              ? videoCoordinator.bubbleOffset.value
              : controller.bubbleOffset.value;

      return Positioned(
        left: offset.dx,
        top: offset.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            final currentOffset =
                showVideo
                    ? videoCoordinator.bubbleOffset.value
                    : controller.bubbleOffset.value;
            final newOffset = currentOffset + details.delta;
            final clampedOffset = Offset(
              newOffset.dx.clamp(8, size.width - 72),
              newOffset.dy.clamp(80, size.height - 160),
            );
            if (showVideo) {
              videoCoordinator.bubbleOffset.value = clampedOffset;
            } else {
              controller.bubbleOffset.value = clampedOffset;
            }
          },
          onTap: () {
            if (showVideo) {
              videoCoordinator.restore();
            } else {
              controller.isMinimized.value = false;
              Get.toNamed("/matching");
            }
          },
          child: _bubble(context, isVideo: showVideo),
        ),
      );
    });
  }

  Widget _bubble(BuildContext context, {required bool isVideo}) {
    final theme = Theme.of(context);
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          width: 2,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBorder
                  : AppTheme.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.25),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isVideo ? Iconsax.video : Iconsax.search_normal,
            color: Colors.white,
            size: 18,
          ),

          const SizedBox(height: 4),

          _timer(theme, isVideo: isVideo),

          const SizedBox(height: 2),

          AnimatedDots(size: 4, color: Colors.white),
        ],
      ),
    );
  }

  Widget _timer(ThemeData theme, {required bool isVideo}) {
    return Obx(() {
      final seconds =
          isVideo
              ? videoCoordinator.elapsedSeconds.value
              : controller.elapsedSeconds.value;
      final min = seconds ~/ 60;
      final sec = seconds % 60;

      return Text(
        "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}",
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      );
    });
  }
}
