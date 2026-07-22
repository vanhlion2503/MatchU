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
          body: _VideoStageHost(controller: controller),
        ),
      ),
    );
  }
}

enum _VideoStageGroup { searching, call, error }

class _VideoStageHost extends StatefulWidget {
  const _VideoStageHost({required this.controller});

  final VideoMatchingController controller;

  @override
  State<_VideoStageHost> createState() => _VideoStageHostState();
}

class _VideoStageHostState extends State<_VideoStageHost> {
  late _VideoStageGroup _group;
  late final Worker _phaseWorker;

  @override
  void initState() {
    super.initState();
    _group = _groupFor(widget.controller.phase.value);
    _phaseWorker = ever<VideoMatchingPhase>(widget.controller.phase, (phase) {
      final nextGroup = _groupFor(phase);
      if (nextGroup == _group || !mounted) return;
      setState(() => _group = nextGroup);
    });
  }

  @override
  void dispose() {
    _phaseWorker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_group) {
      _VideoStageGroup.searching => VideoSearchingStage(
        controller: widget.controller,
      ),
      _VideoStageGroup.call => VideoCallStage(controller: widget.controller),
      _VideoStageGroup.error => _ErrorStage(controller: widget.controller),
    };
  }

  _VideoStageGroup _groupFor(VideoMatchingPhase phase) {
    return switch (phase) {
      VideoMatchingPhase.preparing ||
      VideoMatchingPhase.searching => _VideoStageGroup.searching,
      VideoMatchingPhase.connecting ||
      VideoMatchingPhase.active ||
      VideoMatchingPhase.ending ||
      VideoMatchingPhase.converting => _VideoStageGroup.call,
      VideoMatchingPhase.ended => _VideoStageGroup.call,
      VideoMatchingPhase.error => _VideoStageGroup.error,
    };
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
