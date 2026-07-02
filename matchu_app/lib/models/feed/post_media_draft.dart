import 'dart:io';

import 'package:matchu_app/models/feed/media_model.dart';

class PostMediaDraft {
  const PostMediaDraft({
    required this.file,
    required this.type,
    required this.fileName,
    this.durationMs,
  });

  final File file;
  final PostMediaType type;
  final String fileName;
  final int? durationMs;

  bool get isImage => type == PostMediaType.image;
  bool get isVideo => type == PostMediaType.video;
  bool get isAudio => type == PostMediaType.audio;
}
