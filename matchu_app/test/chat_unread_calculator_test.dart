import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/services/chat/chat_service.dart';

void main() {
  test('calculates unread count and ignores blocked conversations', () {
    final total = calculateTotalUnreadFromRooms(
      currentUid: 'me',
      blockedUserIds: {'blocked'},
      rooms: [
        {
          'participants': ['me', 'friend'],
          'unread': {'me': 3},
        },
        {
          'participants': ['me', 'blocked'],
          'unread': {'me': 9},
        },
      ],
    );

    expect(total, 3);
  });

  test('handles malformed and numeric unread values safely', () {
    final total = calculateTotalUnreadFromRooms(
      currentUid: 'me',
      rooms: [
        {
          'participants': ['me', 'friend-a'],
          'unread': {'me': 2.8},
        },
        {
          'participants': ['me', 'friend-b'],
          'unread': {'me': '4'},
        },
        {
          'participants': ['me', 'friend-c'],
          'unread': {'me': -2},
        },
      ],
    );

    expect(total, 2);
  });
}
