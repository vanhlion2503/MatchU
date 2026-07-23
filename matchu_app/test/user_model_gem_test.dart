import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/user_model.dart';

void main() {
  UserModel userFrom(Map<String, dynamic> data) {
    return UserModel.fromJson(data, 'user-1');
  }

  test('reads and serializes the gem balance', () {
    final user = userFrom({'gem': 15});

    expect(user.gem, UserModel.initialGemBalance);
    expect(user.toJson()['gem'], UserModel.initialGemBalance);
    expect(user.copyWith(gem: 9).gem, 9);
  });

  test('legacy users without gem receive the initial balance', () {
    expect(userFrom(const {}).gem, UserModel.initialGemBalance);
  });

  test('invalid or negative gem balances never reach the UI', () {
    expect(userFrom({'gem': -4}).gem, 0);
    expect(userFrom({'gem': '15'}).gem, 0);
  });
}
