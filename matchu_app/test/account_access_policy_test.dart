import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/account_access/account_access_model.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 12);

  test('legacy account without status remains allowed', () {
    final decision = AccountAccessPolicy.evaluate(
      accountStatus: '',
      restriction: null,
      feature: AccountFeature.posts,
      now: now,
    );

    expect(decision.allowed, isTrue);
  });

  test('active account remains allowed', () {
    final decision = AccountAccessPolicy.evaluate(
      accountStatus: 'active',
      restriction: null,
      feature: AccountFeature.chat,
      now: now,
    );

    expect(decision.allowed, isTrue);
  });

  test('restriction blocks only configured features', () {
    final restriction = AccountRestriction(
      features: const {AccountFeature.posts, AccountFeature.chat},
      reason: 'Vi phạm tiêu chuẩn cộng đồng',
      expiresAt: now.add(const Duration(days: 1)),
    );

    final blocked = AccountAccessPolicy.evaluate(
      accountStatus: 'restricted',
      restriction: restriction,
      feature: AccountFeature.posts,
      now: now,
    );
    final allowed = AccountAccessPolicy.evaluate(
      accountStatus: 'restricted',
      restriction: restriction,
      feature: AccountFeature.comments,
      now: now,
    );

    expect(blocked.allowed, isFalse);
    expect(blocked.code, 'feature-restricted');
    expect(blocked.message, contains('Vi phạm tiêu chuẩn cộng đồng'));
    expect(allowed.allowed, isTrue);
  });

  test(
    'expired restriction is allowed without waiting for profile cleanup',
    () {
      final decision = AccountAccessPolicy.evaluate(
        accountStatus: 'restricted',
        restriction: AccountRestriction(
          features: const {AccountFeature.matching},
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
        feature: AccountFeature.matching,
        now: now,
      );

      expect(decision.allowed, isTrue);
    },
  );

  test('suspended and malformed restricted accounts fail closed', () {
    final suspended = AccountAccessPolicy.evaluate(
      accountStatus: 'suspended',
      restriction: null,
      feature: AccountFeature.comments,
      now: now,
    );
    final malformed = AccountAccessPolicy.evaluate(
      accountStatus: 'restricted',
      restriction: null,
      feature: AccountFeature.comments,
      now: now,
    );

    expect(suspended.allowed, isFalse);
    expect(suspended.code, 'account-suspended');
    expect(malformed.allowed, isFalse);
    expect(malformed.code, 'account-restricted');
  });
}
