import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';

class PostVideoThumbnail extends StatefulWidget {
  const PostVideoThumbnail({
    super.key,
    required this.url,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.useIntrinsicAspectRatio = true,
  });

  final String url;
  final BorderRadius borderRadius;
  final bool useIntrinsicAspectRatio;

  @override
  State<PostVideoThumbnail> createState() => _PostVideoThumbnailState();
}

class _PostVideoThumbnailState extends State<PostVideoThumbnail>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant PostVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _setupController();
    }
  }

  void _setupController() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      _initializeFuture = Future<void>.error(
        const FormatException('Invalid video url'),
      );
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    _initializeFuture = controller.initialize().then((_) async {
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }

    final isCompleted =
        controller.value.duration > Duration.zero &&
        controller.value.position >= controller.value.duration;

    if (isCompleted) {
      await controller.seekTo(Duration.zero);
    }

    await controller.play();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  Widget _wrapContent({
    required Widget child,
    required double fallbackAspectRatio,
  }) {
    if (!widget.useIntrinsicAspectRatio) {
      return SizedBox.expand(child: child);
    }

    return AspectRatio(aspectRatio: fallbackAspectRatio, child: child);
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          final controller = _controller;
          final isReady = controller?.value.isInitialized ?? false;

          if (!isReady) {
            return _wrapContent(
              fallbackAspectRatio: 16 / 9,
              child: _VideoPlaceholder(
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                hasError: snapshot.hasError,
              ),
            );
          }

          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller!,
            builder: (context, value, _) {
              final aspectRatio =
                  value.aspectRatio > 0 ? value.aspectRatio : (16 / 9);

              return Material(
                color: Colors.black,
                child: InkWell(
                  onTap: _togglePlay,
                  child: _wrapContent(
                    fallbackAspectRatio: aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: value.size.width,
                            height: value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.08),
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                        if (!value.isPlaying)
                          const Center(
                            child: Icon(
                              Iconsax.play_circle,
                              size: 62,
                              color: Colors.white,
                            ),
                          ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              value.isPlaying ? 'Đang phát' : 'Video',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.isLoading, required this.hasError});

  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      child: Center(
        child:
            hasError
                ? const Icon(
                  Iconsax.video_slash,
                  color: Colors.white70,
                  size: 40,
                )
                : isLoading
                ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
                : const Icon(
                  Iconsax.play_circle,
                  color: Colors.white70,
                  size: 40,
                ),
      ),
    );
  }
}
