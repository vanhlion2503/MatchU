import 'dart:async';
import 'dart:math' as math;

import 'package:matchu_app/translations/localized_material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:just_audio/just_audio.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class PostVoicePlayer extends StatefulWidget {
  const PostVoicePlayer({
    super.key,
    required this.url,
    this.localPath,
    this.durationMs,
    this.compact = false,
    this.backgroundColor,
    this.borderColor,
    this.activeColor,
    this.inactiveColor,
    this.iconColor,
    this.textColor,
  });

  final String url;
  final String? localPath;
  final int? durationMs;
  final bool compact;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? iconColor;
  final Color? textColor;

  @override
  State<PostVoicePlayer> createState() => _PostVoicePlayerState();
}

class _PostVoicePlayerState extends State<PostVoicePlayer> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  bool _isLoading = false;
  bool _cancelLoadRequest = false;
  int _loadGeneration = 0;
  Future<void>? _loadInFlight;
  String? _loadedSourceKey;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(_player.seek(Duration.zero));
        unawaited(_player.pause());
        _position = Duration.zero;
      }
      setState(() {});
    });
    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
  }

  @override
  void didUpdateWidget(covariant PostVoicePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.localPath != widget.localPath) {
      _duration = null;
      _position = Duration.zero;
      _loadedSourceKey = null;
      _cancelLoadRequest = true;
      _loadGeneration++;
      unawaited(_player.stop());
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final sourceKey = _sourceKey();
    if (sourceKey == null) return;

    try {
      if (_isLoading) {
        _cancelLoadRequest = true;
        _loadGeneration++;
        await _player.pause();
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      if (_player.playing) {
        await _player.pause();
        return;
      }

      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }

      _cancelLoadRequest = false;
      await _ensureSourceLoaded(sourceKey);
      if (!mounted || _cancelLoadRequest) return;
      if (mounted) setState(() => _isLoading = false);
      unawaited(_playLoadedSource());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể phát ghi âm lúc này.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playLoadedSource() async {
    try {
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể phát ghi âm lúc này.')),
      );
    }
  }

  Future<void> _ensureSourceLoaded(String sourceKey) async {
    final previousLoad = _loadInFlight;
    if (previousLoad != null) {
      if (mounted) setState(() => _isLoading = true);
      await previousLoad;
      if (!mounted) return;
    }

    if (_loadedSourceKey == sourceKey &&
        _player.processingState != ProcessingState.idle) {
      return;
    }

    final source = _resolveSource();
    if (source == null) return;

    final generation = ++_loadGeneration;
    _cancelLoadRequest = false;
    if (mounted) setState(() => _isLoading = true);

    final loadFuture = _player.setAudioSource(source, preload: true);
    final inFlight = loadFuture.then((_) {});
    _loadInFlight = inFlight;
    try {
      final duration = await loadFuture;
      if (!mounted || generation != _loadGeneration) return;
      _duration = duration;
      _loadedSourceKey = sourceKey;
    } finally {
      if (identical(_loadInFlight, inFlight)) {
        _loadInFlight = null;
      }
    }
  }

  AudioSource? _resolveSource() {
    final url = widget.url.trim();
    if (url.isNotEmpty) {
      return AudioSource.uri(Uri.parse(url));
    }

    final localPath = widget.localPath?.trim() ?? '';
    if (localPath.isNotEmpty) {
      return AudioSource.uri(Uri.file(localPath));
    }

    return null;
  }

  String? _sourceKey() {
    final url = widget.url.trim();
    if (url.isNotEmpty) return 'url:$url';

    final localPath = widget.localPath?.trim() ?? '';
    if (localPath.isNotEmpty) return 'file:$localPath';

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final fallbackDuration =
        widget.durationMs == null
            ? null
            : Duration(milliseconds: widget.durationMs!);
    final duration = _duration ?? _player.duration ?? fallbackDuration;
    final displayDuration =
        _position > Duration.zero ? _position : (duration ?? _position);
    final progress =
        duration == null || duration.inMilliseconds <= 0
            ? 0.0
            : (_position.inMilliseconds / duration.inMilliseconds).clamp(
              0.0,
              1.0,
            );
    final hasPlayableSource =
        widget.url.trim().isNotEmpty ||
        (widget.localPath?.trim().isNotEmpty ?? false);
    final backgroundColor = widget.backgroundColor ?? palette.surfaceMuted;
    final borderColor =
        widget.borderColor ?? palette.border.withValues(alpha: 0.9);
    final iconColor = widget.iconColor ?? palette.iconPrimary;
    final activeColor = widget.activeColor ?? palette.textPrimary;
    final inactiveColor =
        widget.inactiveColor ?? palette.border.withValues(alpha: 0.9);
    final textColor = widget.textColor ?? palette.textSecondary;
    final radius = BorderRadius.circular(10);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.compact ? 280 : 420),
      child: Material(
        color: backgroundColor,
        borderRadius: radius,
        child: InkWell(
          onTap: hasPlayableSource ? _togglePlayback : null,
          borderRadius: radius,
          child: Container(
            height: widget.compact ? 48 : 54,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child:
                        _isLoading || !hasPlayableSource
                            ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: iconColor,
                              ),
                            )
                            : Icon(
                              _player.playing ? Iconsax.pause : Iconsax.play,
                              size: 20,
                              color: iconColor,
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VoiceWaveform(
                    progress: progress,
                    seed: _waveformSeed(widget.url, widget.localPath),
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    barCount: widget.compact ? 22 : 44,
                    maxBarHeight: widget.compact ? 22 : 26,
                  ),
                ),
                SizedBox(width: widget.compact ? 8 : 10),
                SizedBox(
                  width: widget.compact ? 52 : 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatDuration(displayDuration),
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.progress,
    required this.seed,
    required this.activeColor,
    required this.inactiveColor,
    this.barCount = 42,
    this.minBarHeight = 4,
    this.maxBarHeight = 26,
  });

  final double progress;
  final int seed;
  final Color activeColor;
  final Color inactiveColor;
  final int barCount;
  final double minBarHeight;
  final double maxBarHeight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VoiceWaveformPainter(
        progress: progress.clamp(0.0, 1.0),
        seed: seed,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        barCount: barCount,
        minBarHeight: minBarHeight,
        maxBarHeight: maxBarHeight,
      ),
      child: SizedBox(height: maxBarHeight),
    );
  }
}

class ThreadsVoiceRecordingIndicator extends StatefulWidget {
  const ThreadsVoiceRecordingIndicator({
    super.key,
    required this.seconds,
    required this.amplitudes,
    this.compact = false,
    this.visibleSeconds = 42,
  });

  final int seconds;
  final List<double> amplitudes;
  final bool compact;
  final int visibleSeconds;

  @override
  State<ThreadsVoiceRecordingIndicator> createState() =>
      _ThreadsVoiceRecordingIndicatorState();
}

class _ThreadsVoiceRecordingIndicatorState
    extends State<ThreadsVoiceRecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant ThreadsVoiceRecordingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudes.length != widget.amplitudes.length) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final radius = BorderRadius.circular(10);
    final elapsedSeconds = widget.seconds <= 0 ? 1 : widget.seconds;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: radius,
        border: Border.all(color: palette.border.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 12,
          vertical: widget.compact ? 8 : 10,
        ),
        child: Row(
          children: [
            Container(
              width: widget.compact ? 26 : 28,
              height: widget.compact ? 26 : 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.microphone_2,
                size: 16,
                color: theme.colorScheme.onError,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return RecordingWaveform(
                    amplitudes: widget.amplitudes,
                    sampleProgress: _controller.value,
                    visibleSeconds: widget.visibleSeconds,
                    activeColor: palette.textPrimary,
                    inactiveColor: palette.border.withValues(alpha: 0.8),
                    maxBarHeight: widget.compact ? 22 : 28,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: widget.compact ? 48 : 52,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatVoiceDurationFromSeconds(elapsedSeconds),
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingWaveform extends StatelessWidget {
  const RecordingWaveform({
    super.key,
    required this.amplitudes,
    required this.sampleProgress,
    required this.visibleSeconds,
    required this.activeColor,
    required this.inactiveColor,
    this.minBarHeight = 4,
    this.maxBarHeight = 28,
  });

  final List<double> amplitudes;
  final double sampleProgress;
  final int visibleSeconds;
  final Color activeColor;
  final Color inactiveColor;
  final double minBarHeight;
  final double maxBarHeight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RecordingWaveformPainter(
        amplitudes: amplitudes,
        sampleProgress: sampleProgress.clamp(0.0, 1.0),
        visibleSeconds: visibleSeconds,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        minBarHeight: minBarHeight,
        maxBarHeight: maxBarHeight,
      ),
      child: SizedBox(height: maxBarHeight),
    );
  }
}

class _RecordingWaveformPainter extends CustomPainter {
  const _RecordingWaveformPainter({
    required this.amplitudes,
    required this.sampleProgress,
    required this.visibleSeconds,
    required this.activeColor,
    required this.inactiveColor,
    required this.minBarHeight,
    required this.maxBarHeight,
  });

  final List<double> amplitudes;
  final double sampleProgress;
  final int visibleSeconds;
  final Color activeColor;
  final Color inactiveColor;
  final double minBarHeight;
  final double maxBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = math.max(12, visibleSeconds);
    if (size.width <= 0) return;

    final gap = size.width < 180 ? 2.0 : 2.4;
    final barWidth = math.max(
      2.0,
      (size.width - gap * (barCount - 1)) / barCount,
    );
    final step = barWidth + gap;
    final centerY = size.height / 2;
    final samples = amplitudes.isEmpty ? const <double>[0.08] : amplitudes;
    final totalSamples = samples.length;
    final progress = sampleProgress.clamp(0.0, 1.0);
    final trailingGhostCount = totalSamples < barCount ? 1 : 0;
    final totalWithFraction = totalSamples + progress;
    final visibleCapacity = barCount - trailingGhostCount;
    final shouldScroll = totalWithFraction > visibleCapacity;
    final scrollOffset =
        shouldScroll ? (totalWithFraction - visibleCapacity) : 0.0;
    final activePaint =
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;
    final inactivePaint =
        Paint()
          ..color = inactiveColor
          ..style = PaintingStyle.fill;

    canvas
      ..save()
      ..clipRect(Offset.zero & size);

    final firstSample = math.max(0, scrollOffset.floor());
    final lastSample = math.min(totalSamples - 1, firstSample + barCount + 1);
    for (var index = firstSample; index <= lastSample; index++) {
      final x = (index - scrollOffset) * step;
      if (x + barWidth < 0 || x > size.width) continue;

      final sample = samples[index].clamp(0.0, 1.0);
      final height = _heightFromAmplitude(sample);
      final clampedHeight = height.clamp(minBarHeight, maxBarHeight);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - clampedHeight / 2, barWidth, clampedHeight),
        Radius.circular(barWidth),
      );

      canvas.drawRRect(rect, activePaint);
    }

    if (trailingGhostCount > 0) {
      final x = (totalSamples - scrollOffset) * step;
      if (x <= size.width) {
        final latestAmplitude = samples.last.clamp(0.0, 1.0);
        final nextHeight =
            _heightFromAmplitude(latestAmplitude) *
            math.max(0.16, progress.clamp(0.0, 1.0));
        final clampedHeight = nextHeight.clamp(minBarHeight, maxBarHeight);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centerY - clampedHeight / 2,
            barWidth,
            clampedHeight,
          ),
          Radius.circular(barWidth),
        );
        canvas.drawRRect(rect, inactivePaint);
      }
    }

    canvas.restore();
  }

  double _heightFromAmplitude(double amplitude) {
    final eased = math.pow(amplitude.clamp(0.0, 1.0), 1.35).toDouble();
    return minBarHeight + (maxBarHeight - minBarHeight) * eased;
  }

  @override
  bool shouldRepaint(covariant _RecordingWaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.sampleProgress != sampleProgress ||
        oldDelegate.visibleSeconds != visibleSeconds ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.minBarHeight != minBarHeight ||
        oldDelegate.maxBarHeight != maxBarHeight;
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  const _VoiceWaveformPainter({
    required this.progress,
    required this.seed,
    required this.activeColor,
    required this.inactiveColor,
    required this.barCount,
    required this.minBarHeight,
    required this.maxBarHeight,
  });

  final double progress;
  final int seed;
  final Color activeColor;
  final Color inactiveColor;
  final int barCount;
  final double minBarHeight;
  final double maxBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.width <= 0) return;

    final gap = size.width < 180 ? 2.0 : 2.4;
    final barWidth = math.max(
      2.0,
      (size.width - gap * (barCount - 1)) / barCount,
    );
    final centerY = size.height / 2;
    final activeIndex = (barCount * progress).floor();
    final activePaint =
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;
    final inactivePaint =
        Paint()
          ..color = inactiveColor
          ..style = PaintingStyle.fill;

    for (var index = 0; index < barCount; index++) {
      final noise = _noise(index, seed);
      final envelope = math.sin((index / math.max(1, barCount - 1)) * math.pi);
      final height =
          minBarHeight +
          (maxBarHeight - minBarHeight) *
              (0.25 + noise * 0.55 + envelope * 0.2);
      final clampedHeight = height.clamp(minBarHeight, maxBarHeight);
      final left = index * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          centerY - clampedHeight / 2,
          barWidth,
          clampedHeight,
        ),
        Radius.circular(barWidth),
      );
      canvas.drawRRect(
        rect,
        index <= activeIndex ? activePaint : inactivePaint,
      );
    }
  }

  double _noise(int index, int seed) {
    final value = math.sin((index + 1) * 12.9898 + seed * 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.seed != seed ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.barCount != barCount ||
        oldDelegate.minBarHeight != minBarHeight ||
        oldDelegate.maxBarHeight != maxBarHeight;
  }
}

String formatVoiceDurationFromSeconds(int seconds) {
  return _formatDuration(Duration(seconds: seconds));
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

int _waveformSeed(String url, String? localPath) {
  final source = url.trim().isNotEmpty ? url.trim() : localPath?.trim() ?? '';
  if (source.isEmpty) return 11;
  return source.codeUnits.fold<int>(0, (value, unit) => value + unit);
}
