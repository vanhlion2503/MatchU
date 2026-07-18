import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/chat_notification_payload.dart';

void main() {
  test('parses a valid chat notification payload', () {
    final payload = ChatNotificationPayload.fromJson({
      'type': 'chat_message',
      'roomId': 'room-1',
      'senderUid': 'user-2',
      'messageId': 'message-3',
      'pendingCount': '4',
    });

    expect(payload, isNotNull);
    expect(payload!.roomId, 'room-1');
    expect(payload.pendingCount, 4);
  });

  test('rejects malformed or unrelated payloads', () {
    expect(
      ChatNotificationPayload.fromJson({
        'type': 'post_like',
        'roomId': 'room-1',
        'senderUid': 'user-2',
      }),
      isNull,
    );
    expect(
      ChatNotificationPayload.fromJson({
        'type': 'chat_message',
        'roomId': '',
        'senderUid': 'user-2',
      }),
      isNull,
    );
  });

  test('payload string round trip preserves navigation fields', () {
    const source = ChatNotificationPayload(
      roomId: 'room-1',
      senderUid: 'user-2',
      messageId: 'message-3',
      deliveryMode: 'push',
      pendingCount: 2,
    );

    final parsed = ChatNotificationPayload.fromPayloadString(
      source.toPayloadString(),
    );

    expect(parsed?.roomId, source.roomId);
    expect(parsed?.messageId, source.messageId);
    expect(parsed?.deliveryMode, source.deliveryMode);
  });
}
