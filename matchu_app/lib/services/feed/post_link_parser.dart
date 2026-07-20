import 'package:matchu_app/services/feed/post_share_service.dart';

class PostLinkParser {
  PostLinkParser({Uri? shareBaseUri})
    : shareBaseUri =
          shareBaseUri ?? Uri.parse(PostShareService.defaultShareBaseUrl);

  final Uri shareBaseUri;

  String? parsePostId(Uri uri) {
    final isCanonicalHttpsLink =
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == shareBaseUri.host.toLowerCase();
    final isCustomScheme = uri.scheme.toLowerCase() == 'matchu';

    if (isCanonicalHttpsLink) {
      return _postIdFromPath(uri.pathSegments);
    }
    if (!isCustomScheme) return null;

    // Supported fallbacks: matchu://post/{id} and matchu:///p/{id}.
    if (uri.host.toLowerCase() == 'post' && uri.pathSegments.isNotEmpty) {
      return _normalizePostId(uri.pathSegments.first);
    }
    return _postIdFromPath(uri.pathSegments);
  }

  String? _postIdFromPath(List<String> segments) {
    final normalizedSegments =
        segments.where((segment) => segment.trim().isNotEmpty).toList();
    if (normalizedSegments.length != 2 ||
        normalizedSegments.first.toLowerCase() != 'p') {
      return null;
    }
    return _normalizePostId(normalizedSegments.last);
  }

  String? _normalizePostId(String rawPostId) {
    final postId = rawPostId.trim();
    if (postId.isEmpty || postId.length > 200) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(postId)) return null;
    return postId;
  }
}
