import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/notification/post_engagement_notification_payload.dart';

void main() {
  test('parses string counters from an FCM data payload', () {
    final payload = PostEngagementNotificationPayload.fromJson({
      'type': 'post_engagement',
      'postId': 'post-1',
      'commentId': 'comment-2',
      'pendingCount': '5',
      'likeCount': '3',
      'commentCount': '2',
      'title': '5 t\u01B0\u01A1ng t\u00E1c m\u1EDBi',
      'body': '3 l\u01B0\u1EE3t th\u00EDch v\u00E0 2 b\u00ECnh lu\u1EADn',
    });

    expect(payload, isNotNull);
    expect(payload!.postId, 'post-1');
    expect(payload.commentId, 'comment-2');
    expect(payload.pendingCount, 5);
    expect(payload.likeCount, 3);
    expect(payload.commentCount, 2);
  });

  test('rejects unrelated or incomplete payloads', () {
    expect(
      PostEngagementNotificationPayload.fromJson({
        'type': 'chat_message',
        'postId': 'post-1',
        'title': 'title',
        'body': 'body',
      }),
      isNull,
    );
    expect(
      PostEngagementNotificationPayload.fromJson({
        'type': 'post_engagement',
        'title': 'title',
        'body': 'body',
      }),
      isNull,
    );
  });

  test('round-trips through the local notification payload', () {
    const original = PostEngagementNotificationPayload(
      postId: 'post-9',
      title: 'Ti\u00EAu \u0111\u1EC1',
      body: 'N\u1ED9i dung',
      pendingCount: 4,
      likeCount: 4,
    );

    final decoded = PostEngagementNotificationPayload.fromPayloadString(
      original.toPayloadString(),
    );
    expect(decoded?.postId, original.postId);
    expect(decoded?.pendingCount, original.pendingCount);
    expect(decoded?.title, original.title);
  });
}
