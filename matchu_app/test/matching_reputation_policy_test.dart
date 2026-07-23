import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/matching/matching_mode.dart';
import 'package:matchu_app/models/matching/matching_reputation_policy.dart';

void main() {
  group('MatchingReputationPolicy', () {
    test('temp chat requires at least 80 reputation points', () {
      expect(MatchingReputationPolicy.canUse(MatchingMode.chat, 79), isFalse);
      expect(MatchingReputationPolicy.canUse(MatchingMode.chat, 80), isTrue);
    });

    test('video matching requires at least 90 reputation points', () {
      expect(MatchingReputationPolicy.canUse(MatchingMode.video, 89), isFalse);
      expect(MatchingReputationPolicy.canUse(MatchingMode.video, 90), isTrue);
    });

    test('legacy profiles without a score keep the default score', () {
      expect(MatchingReputationPolicy.canUse(MatchingMode.video, null), isTrue);
      expect(MatchingReputationPolicy.scoreFrom('85'), 85);
    });
  });
}
