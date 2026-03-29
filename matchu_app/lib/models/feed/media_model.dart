enum PostMediaType { image, video }

class MediaModel {
  const MediaModel({required this.url, required this.type});

  final String url;
  final PostMediaType type;

  bool get isImage => type == PostMediaType.image;
  bool get isVideo => type == PostMediaType.video;

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      url: (json['url'] ?? '').toString().trim(),
      type: _parseType(json['type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'type': type.name};
  }

  MediaModel copyWith({String? url, PostMediaType? type}) {
    return MediaModel(url: url ?? this.url, type: type ?? this.type);
  }

  static PostMediaType _parseType(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == PostMediaType.video.name) {
      return PostMediaType.video;
    }
    return PostMediaType.image;
  }
}
