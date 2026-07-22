import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/matching/video_matching_controller.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:matchu_app/views/matching/video/video_call_stage.dart';
import 'package:matchu_app/views/matching/video/video_searching_stage.dart';

class VideoMatchingView extends GetView<VideoMatchingController> {
  const VideoMatchingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: controller.allowRoutePop.value,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final currentPhase = controller.phase.value;
          if (currentPhase == VideoMatchingPhase.searching ||
              currentPhase == VideoMatchingPhase.preparing ||
              currentPhase == VideoMatchingPhase.error) {
            controller.cancelSearch();
          } else {
            controller.leaveRoom(findNext: false);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Obx(() {
            switch (controller.phase.value) {
              case VideoMatchingPhase.preparing:
              case VideoMatchingPhase.searching:
                return VideoSearchingStage(controller: controller);
              case VideoMatchingPhase.connecting:
              case VideoMatchingPhase.active:
              case VideoMatchingPhase.ending:
              case VideoMatchingPhase.converting:
                return VideoCallStage(controller: controller);
              case VideoMatchingPhase.ended:
                return _EndedStage(controller: controller);
              case VideoMatchingPhase.error:
                return _ErrorStage(controller: controller);
            }
          }),
        ),
      ),
    );
  }
}

class _EndedStage extends StatelessWidget {
  const _EndedStage({required this.controller});

  final VideoMatchingController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.errorContainer,
                ),
                child: Icon(
                  Iconsax.call_slash,
                  size: 34,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Cuộc gọi đã kết thúc',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn có thể tìm một người mới hoặc quay lại.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => controller.leaveRoom(findNext: true),
                  icon: const Icon(Iconsax.refresh),
                  label: const Text('Tìm người mới'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => controller.leaveRoom(findNext: false),
                  child: const Text('Quay lại'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorStage extends StatelessWidget {
  const _ErrorStage({required this.controller});

  final VideoMatchingController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.video_slash,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                'Không thể kết nối video',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                controller.errorMessage.value ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.closeError,
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.retry,
                      child: const Text('Thử lại'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
