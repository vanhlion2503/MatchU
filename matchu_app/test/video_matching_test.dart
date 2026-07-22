import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/matching/matching_mode.dart';
import 'package:matchu_app/models/queue_user_model.dart';
import 'package:matchu_app/translations/video_matching_translations.dart';

void main() {
  test('video matching dictionaries contain identical keys', () {
    expect(
      videoMatchingVietnameseTranslations.keys.toSet(),
      videoMatchingEnglishTranslations.keys.toSet(),
    );
  });

  test('queue user serializes the selected matching mode', () {
    final user = QueueUserModel(
      uid: 'user-a',
      gender: 'male',
      targetGender: 'random',
      sessionId: 'session-a',
      matchingMode: MatchingMode.video,
      avgChatRating: 5,
      createdAt: DateTime.utc(2026, 7, 22),
    );

    expect(user.toJson()['matchingMode'], 'video');
    expect(
      QueueUserModel.fromJson(user.toJson()).matchingMode,
      MatchingMode.video,
    );
  });

  test('legacy queue entries default to chat matching', () {
    final user = QueueUserModel.fromJson({
      'uid': 'user-a',
      'gender': 'male',
      'targetGender': 'random',
      'sessionId': 'session-a',
      'avgChatRating': 5,
      'createdAt': DateTime.utc(2026, 7, 22).toIso8601String(),
    });

    expect(user.matchingMode, MatchingMode.chat);
  });
}
