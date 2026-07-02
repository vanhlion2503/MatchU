import 'dart:async';

import 'package:flutter/material.dart';
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
  });

  final String url;
  final String? localPath;
  final int? durationMs;
  final bool compact;

  @override
  State<PostVoicePlayer> createState() => _PostVoicePlayerState();
}

class _PostVoicePlayerState extends State<PostVoicePlayer> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  bool _isLoading = false;
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
    if (_isLoading) return;

    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }

      if (_player.duration == null) {
        setState(() => _isLoading = true);
        final source = _resolveSource();
        if (source == null) return;
        _duration = await _player.setAudioSource(source);
      }

      await _player.play();
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

  AudioSource? _resolveSource() {
    final localPath = widget.localPath?.trim() ?? '';
    if (localPath.isNotEmpty) {
      return AudioSource.uri(Uri.file(localPath));
    }

    final url = widget.url.trim();
    if (url.isEmpty) return null;
    return AudioSource.uri(Uri.parse(url));
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
    final progress =
        duration == null || duration.inMilliseconds <= 0
            ? 0.0
            : (_position.inMilliseconds / duration.inMilliseconds).clamp(
              0.0,
              1.0,
            );
    final isPlaying = _player.playing;
    final hasPlayableSource =
        widget.url.trim().isNotEmpty ||
        (widget.localPath?.trim().isNotEmpty ?? false);
    final isPendingLocal = !hasPlayableSource;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.compact ? 260 : 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(widget.compact ? 16 : 18),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 12,
            vertical: widget.compact ? 8 : 10,
          ),
          child: Row(
            children: [
              Material(
                color: theme.colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isPendingLocal ? null : _togglePlayback,
                  child: SizedBox(
                    width: widget.compact ? 34 : 38,
                    height: widget.compact ? 34 : 38,
                    child: Center(
                      child:
                          _isLoading || isPendingLocal
                              ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                              : Icon(
                                isPlaying ? Iconsax.pause : Iconsax.play,
                                size: 18,
                                color: theme.colorScheme.onPrimary,
                              ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.microphone_2,
                          size: 15,
                          color: palette.iconMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Ghi âm',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(duration ?? _position),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: progress,
                        backgroundColor: palette.border.withValues(alpha: 0.6),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
