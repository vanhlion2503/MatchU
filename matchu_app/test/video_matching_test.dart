import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/controllers/matching/video_matching_session_coordinator.dart';
import 'package:matchu_app/models/matching/matching_mode.dart';
import 'package:matchu_app/models/matching/video_matching_access_proof.dart';
import 'package:matchu_app/models/queue_user_model.dart';
import 'package:matchu_app/translations/video_matching_translations.dart';
import 'package:matchu_app/views/matching/video_matching_view.dart';

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

  test('minimized video matching session can be restored without ending', () {
    final coordinator = VideoMatchingSessionCoordinator();
    var restored = false;

    coordinator.begin(onRestore: () => restored = true);
    coordinator.updateElapsed(12);

    expect(coordinator.minimize(), isTrue);
    expect(coordinator.isActive.value, isTrue);
    expect(coordinator.isMinimized.value, isTrue);
    expect(coordinator.elapsedSeconds.value, 12);

    coordinator.restore();

    expect(restored, isTrue);
    expect(coordinator.isActive.value, isTrue);
    expect(coordinator.isMinimized.value, isFalse);

    coordinator.finish();
    expect(coordinator.isActive.value, isFalse);
  });

  test('video matching screen can be constructed', () {
    expect(const VideoMatchingView(), isA<VideoMatchingView>());
  });

  test('video face proof keeps an expiry safety margin', () {
    final now = DateTime.utc(2026, 7, 23, 10);
    final proof = VideoMatchingAccessProof(
      id: 'proof-a',
      deviceId: 'device-a',
      expiresAt: now.add(const Duration(minutes: 15)),
    );

    expect(proof.isUsableAt(now), isTrue);
    expect(
      proof.isUsableAt(now.add(const Duration(minutes: 14, seconds: 50))),
      isFalse,
    );
  });
}
