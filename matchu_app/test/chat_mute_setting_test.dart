import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/chat_mute_setting.dart';

void main() {
  test('mute without expiry remains active', () {
    const setting = ChatMuteSetting(userId: 'other-user');

    expect(setting.isActiveAt(DateTime(2030)), isTrue);
  });

  test('timed mute becomes inactive at its expiry', () {
    final expiry = DateTime(2030, 1, 1, 12);
    final setting = ChatMuteSetting(userId: 'other-user', mutedUntil: expiry);

    expect(
      setting.isActiveAt(expiry.subtract(const Duration(milliseconds: 1))),
      isTrue,
    );
    expect(setting.isActiveAt(expiry), isFalse);
    expect(
      setting.isActiveAt(expiry.add(const Duration(milliseconds: 1))),
      isFalse,
    );
  });
}
