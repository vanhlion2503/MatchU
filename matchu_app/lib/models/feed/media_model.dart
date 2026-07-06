enum PostMediaType { image, video, audio }

class MediaModel {
  const MediaModel({
    required this.url,
    required this.type,
    this.durationMs,
    this.storagePath,
    this.mimeType,
  });

  final String url;
  final PostMediaType type;
  final int? durationMs;
  final String? storagePath;
  final String? mimeType;

  bool get isImage => type == PostMediaType.image;
  bool get isVideo => type == PostMediaType.video;
  bool get isAudio => type == PostMediaType.audio;

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      url: (json['url'] ?? '').toString().trim(),
      type: _parseType(json['type']),
      durationMs: _parseDurationMs(json['durationMs']),
      storagePath: _parseNullableString(json['storagePath']),
      mimeType: _parseNullableString(json['mimeType']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type.name,
      if (durationMs != null) 'durationMs': durationMs,
      if (storagePath?.trim().isNotEmpty == true)
        'storagePath': storagePath!.trim(),
      if (mimeType?.trim().isNotEmpty == true) 'mimeType': mimeType!.trim(),
    };
  }

  MediaModel copyWith({
    String? url,
    PostMediaType? type,
    int? durationMs,
    String? storagePath,
    String? mimeType,
  }) {
    return MediaModel(
      url: url ?? this.url,
      type: type ?? this.type,
      durationMs: durationMs ?? this.durationMs,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
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

  static String? _parseNullableString(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
