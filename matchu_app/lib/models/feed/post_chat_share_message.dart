import 'dart:convert';

import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_share_service.dart';

class PostChatShareMessage {
  const PostChatShareMessage({
    required this.postId,
    required this.uri,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.excerpt,
    required this.thumbnailUrl,
  });

  static const String messageType = 'post_share';
  static const int schemaVersion = 1;

  final String postId;
  final Uri uri;
  final String authorName;
  final String authorAvatarUrl;
  final String excerpt;
  final String thumbnailUrl;

  factory PostChatShareMessage.fromPost(
    PostModel post, {
    PostShareService? shareService,
  }) {
    final service = shareService ?? PostShareService();
    final sharePayload = service.buildPayload(post);
    final reference = post.isRepostOnly ? post.referencePost : null;
    final author = reference?.author ?? post.author;
    final content = (reference?.content ?? post.content).trim();
    final media = reference?.media ?? post.media;
    final firstVisual = media.where((item) => !item.isAudio).firstOrNull;
    final rawAuthorName = author.name.trim();

    return PostChatShareMessage(
      postId: sharePayload.postId,
      uri: sharePayload.uri,
      authorName:
          rawAuthorName.isNotEmpty
              ? rawAuthorName
              : author.nickname.trim().isNotEmpty
              ? '@${author.nickname.trim()}'
              : 'MatchU',
      authorAvatarUrl: author.avatar.trim(),
      excerpt: _truncate(content, 180),
      thumbnailUrl:
          (firstVisual?.thumbnailUrl?.trim().isNotEmpty == true
                  ? firstVisual!.thumbnailUrl
                  : firstVisual?.url)
              ?.trim() ??
          '',
    );
  }

  String encode() => jsonEncode(<String, dynamic>{
    'v': schemaVersion,
    'postId': postId,
    'uri': uri.toString(),
    'authorName': authorName,
    'authorAvatarUrl': authorAvatarUrl,
    'excerpt': excerpt,
    'thumbnailUrl': thumbnailUrl,
  });

  static PostChatShareMessage? tryDecode(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      if (json['v'] != schemaVersion) return null;

      final postId = (json['postId'] ?? '').toString().trim();
      final uri = Uri.tryParse((json['uri'] ?? '').toString().trim());
      if (postId.isEmpty ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty) {
        return null;
      }

      return PostChatShareMessage(
        postId: postId,
        uri: uri,
        authorName: (json['authorName'] ?? 'MatchU').toString().trim(),
        authorAvatarUrl: (json['authorAvatarUrl'] ?? '').toString().trim(),
        excerpt: (json['excerpt'] ?? '').toString().trim(),
        thumbnailUrl: (json['thumbnailUrl'] ?? '').toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _truncate(String value, int maxRunes) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final runes = normalized.runes.toList(growable: false);
    if (runes.length <= maxRunes) return normalized;
    return '${String.fromCharCodes(runes.take(maxRunes))}…';
  }
}
