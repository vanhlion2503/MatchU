import 'dart:ui';

import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/repositories/feed/post_share_repository.dart';

class PostShareException implements Exception {
  const PostShareException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PostSharePayload {
  const PostSharePayload({
    required this.postId,
    required this.uri,
    required this.title,
    required this.text,
  });

  final String postId;
  final Uri uri;
  final String title;
  final String text;
}

class PostShareOutcome {
  const PostShareOutcome({required this.payload, required this.status});

  final PostSharePayload payload;
  final PostNativeShareStatus status;
}

class PostShareService {
  PostShareService({PostShareRepository? repository, Uri? baseUri})
    : _repository = repository ?? PlatformPostShareRepository(),
      baseUri = baseUri ?? Uri.parse(defaultShareBaseUrl);

  static const String defaultShareBaseUrl = String.fromEnvironment(
    'MATCHU_SHARE_BASE_URL',
    defaultValue: 'https://matchu-5bd75.web.app',
  );

  final PostShareRepository _repository;
  final Uri baseUri;

  PostSharePayload buildPayload(PostModel post) {
    _ensurePostCanBeShared(post);

    final isPureRepost = post.isRepostOnly && post.referencePost != null;
    final reference = post.referencePost;
    final targetPostId =
        isPureRepost
            ? (post.referencePostId ?? reference?.postId ?? '').trim()
            : post.postId.trim();

    if (targetPostId.isEmpty) {
      throw const PostShareException('Không tìm thấy bài viết để chia sẻ.');
    }

    final authorName =
        isPureRepost
            ? _displayAuthorName(reference!.author)
            : _displayAuthorName(post.author);
    final content = isPureRepost ? reference!.content : post.content;
    final uri = buildPostUri(targetPostId);
    final title =
        authorName.isEmpty
            ? 'Bài viết trên MatchU'
            : 'Bài viết của $authorName trên MatchU';
    final excerpt = _excerpt(content);
    // Keep the visible message compact. The URL is passed separately as a
    // structured URI so receiving apps can render their own link preview.
    final text = <String>[title, if (excerpt.isNotEmpty) excerpt].join('\n\n');

    return PostSharePayload(
      postId: targetPostId,
      uri: uri,
      title: title,
      text: text,
    );
  }

  Uri buildPostUri(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) {
      throw const PostShareException('Mã bài viết không hợp lệ.');
    }

    final baseSegments = baseUri.pathSegments.where((item) => item.isNotEmpty);
    return baseUri.replace(
      pathSegments: <String>[...baseSegments, 'p', normalizedPostId],
      query: null,
      fragment: null,
    );
  }

  Future<PostShareOutcome> share(
    PostModel post, {
    Rect? sharePositionOrigin,
  }) async {
    final payload = buildPayload(post);
    final status = await _repository.share(
      title: payload.title,
      uri: payload.uri,
      sharePositionOrigin: sharePositionOrigin,
    );
    return PostShareOutcome(payload: payload, status: status);
  }

  Future<PostSharePayload> copyLink(PostModel post) async {
    final payload = buildPayload(post);
    await _repository.copyText(payload.uri.toString());
    return payload;
  }

  void _ensurePostCanBeShared(PostModel post) {
    if (post.deletedAt != null ||
        post.referencePost?.isUnavailable == true && post.isRepostOnly) {
      throw const PostShareException('Bài viết này không còn khả dụng.');
    }
    if (!post.isModerationApproved) {
      throw const PostShareException(
        'Bài viết đang được kiểm duyệt hoặc chưa được phê duyệt.',
      );
    }

    final visibility =
        post.isRepostOnly && post.referencePost != null
            ? post.referencePost!.visibility
            : post.visibility;
    if (!visibility.isPublic) {
      throw const PostShareException(
        'Chỉ bài viết công khai mới có thể chia sẻ ra bên ngoài.',
      );
    }
  }

  String _displayAuthorName(PostAuthorModel author) {
    final name = author.name.trim();
    if (name.isNotEmpty) return name;
    return author.nickname.trim();
  }

  String _excerpt(String content) {
    final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';

    const maxRunes = 140;
    final runes = normalized.runes.toList(growable: false);
    if (runes.length <= maxRunes) return normalized;
    return '${String.fromCharCodes(runes.take(maxRunes))}…';
  }
}
