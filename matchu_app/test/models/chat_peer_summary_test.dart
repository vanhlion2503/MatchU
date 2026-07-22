import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';

void main() {
  group('ChatPeerSummary safety policy', () {
    test('warns below 3.6 after five ratings', () {
      const summary = ChatPeerSummary(averageRating: 3.59, totalRatings: 5);

      expect(summary.shouldShowSafetyCaution, isTrue);
      expect(summary.isNewcomer, isFalse);
    });

    test('does not warn at the 3.6 boundary', () {
      const summary = ChatPeerSummary(averageRating: 3.6, totalRatings: 20);

      expect(summary.shouldShowSafetyCaution, isFalse);
    });

    test('does not warn a newcomer from a small rating sample', () {
      const summary = ChatPeerSummary(averageRating: 1.0, totalRatings: 4);

      expect(summary.shouldShowSafetyCaution, isFalse);
      expect(summary.isNewcomer, isTrue);
    });

    test('does not invent a five-star score when no rating exists', () {
      final summary = ChatPeerSummary.fromMap(const <String, dynamic>{});

      expect(summary.hasRatings, isFalse);
      expect(summary.averageRating, 0);
      expect(summary.shouldShowSafetyCaution, isFalse);
    });

    test('normalizes malformed score and count values', () {
      final summary = ChatPeerSummary.fromMap(const <String, dynamic>{
        'avgChatRating': 8,
        'totalChatRatings': -2,
      });

      expect(summary.averageRating, 5);
      expect(summary.totalRatings, 0);
      expect(summary.shouldShowSafetyCaution, isFalse);
    });
  });
}
