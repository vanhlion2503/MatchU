import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';

void main() {
  test('parses a gem conversion claim without changing reputation', () {
    final claim = ReputationClaimResult.fromMap({
      'taskId': 'loginDaily',
      'requested': 1,
      'awarded': 0,
      'gemAwarded': 1,
      'reason': 'claimed_as_gem',
      'reputationBefore': 100,
      'reputationAfter': 100,
      'todayClaimedBefore': 10,
      'todayClaimedAfter': 10,
    });

    expect(claim.awarded, 0);
    expect(claim.gemAwarded, 1);
    expect(claim.reputationAfter, 100);
    expect(claim.todayClaimedAfter, 10);
  });

  test('allows more rewards at max reputation even when daily cap is full', () {
    final state = ReputationDailyState.fromMap({
      'dateKey': '2026-07-25',
      'timezone': 'Asia/Ho_Chi_Minh',
      'dailyCap': 10,
      'todayClaimed': 10,
      'reputationScore': 100,
      'reputationMax': 100,
      'canEarnMore': true,
      'tasks': const <String, dynamic>{},
    });

    expect(state.hasReachedMax, isTrue);
    expect(state.canEarnMore, isTrue);
    expect(state.todayRemaining, 0);
  });
}
