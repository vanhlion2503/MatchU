import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';

const double _defaultFeedVideoAspectRatio = 4 / 5;

class PostVideoThumbnail extends StatefulWidget {
  const PostVideoThumbnail({
    super.key,
    required this.url,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.useIntrinsicAspectRatio = true,
    this.compactControls = false,
    this.reservedAspectRatio = _defaultFeedVideoAspectRatio,
    this.thumbnailUrl,
  });

  final String url;
  final BorderRadius borderRadius;
  final bool useIntrinsicAspectRatio;
  final bool compactControls;
  final double? reservedAspectRatio;
  final String? thumbnailUrl;

  @override
  State<PostVideoThumbnail> createState() => _PostVideoThumbnailState();
}

class _PostVideoThumbnailState extends State<PostVideoThumbnail> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _isMuted = true;

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
      _isMuted = true;
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

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (!mounted) return;

    setState(() {
      _isMuted = nextMuted;
    });
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final wasPlaying = controller.value.isPlaying;
    final initialPosition = controller.value.position;
    await controller.pause();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _PostVideoFullscreenView(
              url: widget.url,
              initialPosition: initialPosition,
              initiallyMuted: _isMuted,
            ),
      ),
    );

    if (!mounted || !_isControllerReady(controller)) return;
    if (wasPlaying) {
      await controller.play();
    }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
        final reservedAspectRatio = widget.reservedAspectRatio;
        final aspectRatio =
            reservedAspectRatio != null && reservedAspectRatio > 0
                ? reservedAspectRatio
                : fallbackAspectRatio;
        final height = _heightForAspectRatio(width, aspectRatio);
        return SizedBox(width: double.infinity, height: height, child: child);
      },
    );
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                thumbnailUrl: widget.thumbnailUrl,
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
                  onTap: widget.compactControls ? _togglePlay : _openFullscreen,
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
                        if (widget.compactControls)
                          const Positioned(
                            top: 10,
                            right: 10,
                            child: _VideoTypeBadge(),
                          ),
                        if (!value.isPlaying)
                          Center(
                            child: InkResponse(
                              onTap: _togglePlay,
                              radius: widget.compactControls ? 30 : 40,
                              child:
                                  widget.compactControls
                                      ? const _CompactPlayButton()
                                      : const Icon(
                                        Iconsax.play_circle,
                                        size: 62,
                                        color: Colors.white,
                                      ),
                            ),
                          ),
                        if (!widget.compactControls) ...[
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _VideoPillButton(
                                  icon:
                                      _isMuted
                                          ? Iconsax.volume_slash
                                          : Iconsax.volume_high,
                                  onTap: _toggleMute,
                                ),
                                const SizedBox(width: 8),
                                _VideoPillButton(
                                  icon: Iconsax.maximize_4,
                                  onTap: _openFullscreen,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: LinearProgressIndicator(
                                value: _progressOf(value),
                                minHeight: 2,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (widget.compactControls)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: LinearProgressIndicator(
                                value: _progressOf(value),
                                minHeight: 2,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
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

bool _isControllerReady(VideoPlayerController controller) {
  return controller.value.isInitialized;
}

double _heightForAspectRatio(double width, double aspectRatio) {
  final resolvedAspectRatio =
      aspectRatio.isFinite && aspectRatio > 0
          ? aspectRatio.clamp(0.72, 2.0).toDouble()
          : 16 / 9;
  final rawHeight = width / resolvedAspectRatio;
  final minHeight = width * 0.56;
  final maxHeight = math.min(width * 1.28, 420.0);
  return rawHeight.clamp(minHeight, maxHeight).toDouble();
}

double _progressOf(VideoPlayerValue value) {
  final durationMs = value.duration.inMilliseconds;
  if (durationMs <= 0) return 0;
  return (value.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _CompactPlayButton extends StatelessWidget {
  const _CompactPlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: const Icon(Iconsax.play, color: Colors.white, size: 24),
    );
  }
}

class _VideoTypeBadge extends StatelessWidget {
  const _VideoTypeBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Icon(Iconsax.video_play, color: Colors.white, size: 15),
      ),
    );
  }
}

class _VideoPillButton extends StatelessWidget {
  const _VideoPillButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkResponse(
        onTap: onTap,
        radius: 19,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _PostVideoFullscreenView extends StatefulWidget {
  const _PostVideoFullscreenView({
    required this.url,
    required this.initialPosition,
    required this.initiallyMuted,
  });

  final String url;
  final Duration initialPosition;
  final bool initiallyMuted;

  @override
  State<_PostVideoFullscreenView> createState() =>
      _PostVideoFullscreenViewState();
}

class _PostVideoFullscreenViewState extends State<_PostVideoFullscreenView> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initiallyMuted;
    _setupController();
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
      await controller.setVolume(_isMuted ? 0 : 1);
      if (widget.initialPosition > Duration.zero &&
          widget.initialPosition < controller.value.duration) {
        await controller.seekTo(widget.initialPosition);
      }
      await controller.play();
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

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (!mounted) return;

    setState(() {
      _isMuted = nextMuted;
    });
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeFuture,
          builder: (context, snapshot) {
            final controller = _controller;
            final isReady = controller?.value.isInitialized ?? false;

            if (!isReady) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: _VideoPlaceholder(
                      thumbnailUrl: null,
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      hasError: snapshot.hasError,
                    ),
                  ),
                  _FullscreenTopBar(onClose: () => Navigator.of(context).pop()),
                ],
              );
            }

            return ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller!,
              builder: (context, value, _) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _togglePlay,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio:
                                value.aspectRatio > 0
                                    ? value.aspectRatio
                                    : 16 / 9,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    ),
                    _FullscreenTopBar(
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    if (!value.isPlaying)
                      Center(
                        child: InkResponse(
                          onTap: _togglePlay,
                          radius: 44,
                          child: const Icon(
                            Iconsax.play_circle,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _FullscreenControls(
                        controller: controller,
                        value: value,
                        isMuted: _isMuted,
                        onTogglePlay: _togglePlay,
                        onToggleMute: _toggleMute,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FullscreenTopBar extends StatelessWidget {
  const _FullscreenTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkResponse(
          onTap: onClose,
          radius: 22,
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.close, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _FullscreenControls extends StatelessWidget {
  const _FullscreenControls({
    required this.controller,
    required this.value,
    required this.isMuted,
    required this.onTogglePlay,
    required this.onToggleMute,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final bool isMuted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                InkResponse(
                  onTap: onTogglePlay,
                  radius: 22,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      value.isPlaying ? Iconsax.pause : Iconsax.play,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                Text(
                  '${_formatDuration(value.position)} / '
                  '${_formatDuration(value.duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkResponse(
                  onTap: onToggleMute,
                  radius: 22,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      isMuted ? Iconsax.volume_slash : Iconsax.volume_high,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({
    required this.isLoading,
    required this.hasError,
    this.thumbnailUrl,
  });

  final bool isLoading;
  final bool hasError;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedThumbnailUrl = thumbnailUrl?.trim() ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (normalizedThumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: normalizedThumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => const ColoredBox(color: Color(0xFF111827)),
            errorWidget:
                (_, __, ___) => const ColoredBox(color: Color(0xFF111827)),
          )
        else
          const ColoredBox(color: Color(0xFF111827)),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: normalizedThumbnailUrl.isNotEmpty ? 0.18 : 0,
            ),
          ),
        ),
        Center(
          child:
              hasError
                  ? const Icon(
                    Iconsax.video_slash,
                    color: Colors.white70,
                    size: 40,
                  )
                  : isLoading
                  ? Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  )
                  : const Icon(
                    Iconsax.play_circle,
                    color: Colors.white70,
                    size: 40,
                  ),
        ),
      ],
    );
  }
}
