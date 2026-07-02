enum PostMediaType { image, video, audio }

class MediaModel {
  const MediaModel({required this.url, required this.type, this.durationMs});

  final String url;
  final PostMediaType type;
  final int? durationMs;

  bool get isImage => type == PostMediaType.image;
  bool get isVideo => type == PostMediaType.video;
  bool get isAudio => type == PostMediaType.audio;

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      url: (json['url'] ?? '').toString().trim(),
      type: _parseType(json['type']),
      durationMs: _parseDurationMs(json['durationMs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type.name,
      if (durationMs != null) 'durationMs': durationMs,
    };
  }

  MediaModel copyWith({String? url, PostMediaType? type, int? durationMs}) {
    return MediaModel(
      url: url ?? this.url,
      type: type ?? this.type,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  static PostMediaType _parseType(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == PostMediaType.video.name) {
      return PostMediaType.video;
    }
    if (normalized == PostMediaType.audio.name ||
        normalized == 'voice' ||
        normalized == 'audio_m4a') {
      return PostMediaType.audio;
    }
    return PostMediaType.image;
  }

  static int? _parseDurationMs(dynamic value) {
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      final parsed = value.toInt();
      return parsed > 0 ? parsed : null;
    }
    return null;
  }
}
