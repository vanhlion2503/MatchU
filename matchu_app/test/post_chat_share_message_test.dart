import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/models/feed/post_chat_share_message.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/stats_model.dart';
import 'package:matchu_app/services/feed/post_share_service.dart';

void main() {
  test('encodes and decodes a compact shared post message', () {
    final message = PostChatShareMessage.fromPost(
      _post(),
      shareService: PostShareService(baseUri: Uri.parse('https://example.com')),
    );

    final decoded = PostChatShareMessage.tryDecode(message.encode());

    expect(decoded, isNotNull);
    expect(decoded!.postId, 'post_123');
    expect(decoded.uri, Uri.parse('https://example.com/p/post_123'));
    expect(decoded.authorName, 'Nguyễn An');
    expect(decoded.excerpt, contains('Nội dung bài viết'));
    expect(decoded.thumbnailUrl, 'https://example.com/preview.jpg');
  });

  test('rejects malformed or non-HTTPS shared post messages', () {
    expect(PostChatShareMessage.tryDecode('not-json'), isNull);
    expect(
      PostChatShareMessage.tryDecode(
        '{"v":1,"postId":"post_123","uri":"javascript:alert(1)"}',
      ),
      isNull,
    );
  });
}

PostModel _post() {
  return PostModel(
    postId: 'post_123',
    authorId: 'author_1',
    postType: PostType.post,
    content: 'Nội dung bài viết',
    media: const <MediaModel>[
      MediaModel(
        url: 'https://example.com/image.jpg',
        thumbnailUrl: 'https://example.com/preview.jpg',
        type: PostMediaType.image,
      ),
    ],
    tags: const <String>[],
    stats: const StatsModel(),
    trendScore: 0,
    trendBucket: 0,
    visibility: PostVisibility.public,
    author: const PostAuthorModel(
      id: 'author_1',
      name: 'Nguyễn An',
      nickname: 'nguyenan',
      avatar: '',
      isVerified: false,
    ),
  );
}
