import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/notification/admin_notification_payload.dart';

void main() {
  test('parses and serializes an admin campaign payload', () {
    final payload = AdminNotificationPayload.fromJson({
      'type': 'admin_campaign',
      'campaignId': 'campaign-1',
      'category': 'maintenance',
      'title': 'Bảo trì hệ thống',
      'body': 'MatchU sẽ bảo trì lúc 23:00.',
      'actionType': 'app_route',
      'actionValue': 'notifications',
    });

    expect(payload, isNotNull);
    expect(payload!.category, 'maintenance');
    expect(
      AdminNotificationPayload.fromPayloadString(
        payload.toPayloadString(),
      )?.campaignId,
      'campaign-1',
    );
  });

  test('rejects another notification type and incomplete content', () {
    expect(
      AdminNotificationPayload.fromJson({
        'type': 'chat_message',
        'campaignId': 'campaign-1',
        'title': 'Title',
        'body': 'Body',
      }),
      isNull,
    );
    expect(
      AdminNotificationPayload.fromJson({
        'type': 'admin_campaign',
        'campaignId': '',
        'title': 'Title',
        'body': 'Body',
      }),
      isNull,
    );
  });
}
