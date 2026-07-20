import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/stats_model.dart';
import 'package:matchu_app/repositories/feed/post_share_repository.dart';
import 'package:matchu_app/services/feed/post_link_parser.dart';
import 'package:matchu_app/services/feed/post_share_service.dart';

void main() {
  group('PostShareService', () {
    test('builds a canonical link for a public post', () {
      final service = PostShareService(
        repository: _FakePostShareRepository(),
        baseUri: Uri.parse('https://example.com'),
      );

      final payload = service.buildPayload(
        _post(postId: 'post_123', content: 'Nội dung bài viết'),
      );

      expect(payload.postId, 'post_123');
      expect(payload.uri.toString(), 'https://example.com/p/post_123');
      expect(payload.text, contains('Nội dung bài viết'));
      expect(payload.text, endsWith('https://example.com/p/post_123'));
    });

    test('a pure repost shares the stable original post link', () {
      final service = PostShareService(
        repository: _FakePostShareRepository(),
        baseUri: Uri.parse('https://example.com'),
      );
      final original = _post(postId: 'original_1', content: 'Bài gốc');
      final repost = _post(
        postId: 'repost_user_original_1',
        postType: PostType.repost,
        content: '',
        referencePost: PostReferenceModel.fromPost(original),
      );

      final payload = service.buildPayload(repost);

      expect(payload.postId, 'original_1');
      expect(payload.uri.toString(), 'https://example.com/p/original_1');
      expect(payload.text, contains('Bài gốc'));
    });

    test('rejects non-public posts', () {
      final service = PostShareService(repository: _FakePostShareRepository());

      expect(
        () => service.buildPayload(
          _post(postId: 'private_1', visibility: PostVisibility.private),
        ),
        throwsA(isA<PostShareException>()),
      );
    });
  });

  group('PostLinkParser', () {
    final parser = PostLinkParser(
      shareBaseUri: Uri.parse('https://example.com'),
    );

    test('parses canonical HTTPS and custom scheme links', () {
      expect(
        parser.parsePostId(Uri.parse('https://example.com/p/post_123')),
        'post_123',
      );
      expect(
        parser.parsePostId(Uri.parse('matchu://post/post_123')),
        'post_123',
      );
    });

    test('rejects another host and malformed paths', () {
      expect(
        parser.parsePostId(Uri.parse('https://attacker.example/p/post_123')),
        isNull,
      );
      expect(
        parser.parsePostId(Uri.parse('https://example.com/p/a/extra')),
        isNull,
      );
      expect(parser.parsePostId(Uri.parse('matchu://post/not%2Fsafe')), isNull);
    });
  });
}

PostModel _post({
  required String postId,
  String content = 'Nội dung',
  PostType postType = PostType.post,
  PostVisibility visibility = PostVisibility.public,
  PostReferenceModel? referencePost,
}) {
  return PostModel(
    postId: postId,
    authorId: 'author_1',
    postType: postType,
    content: content,
    media: const [],
    tags: const [],
    stats: const StatsModel(),
    trendScore: 0,
    trendBucket: 0,
    visibility: visibility,
    author: const PostAuthorModel(
      id: 'author_1',
      name: 'Nguyễn An',
      nickname: 'nguyenan',
      avatar: '',
      isVerified: false,
    ),
    referencePostId: referencePost?.postId,
    referencePost: referencePost,
  );
}

class _FakePostShareRepository implements PostShareRepository {
  @override
  Future<void> copyText(String text) async {}

  @override
  Future<PostNativeShareStatus> share({
    required String title,
    required String text,
    dynamic sharePositionOrigin,
  }) async {
    return PostNativeShareStatus.success;
  }
}
