import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/profile_privacy_settings.dart';

void main() {
  group('ProfilePrivacySettings', () {
    test('keeps legacy user documents public by default', () {
      final settings = ProfilePrivacySettings.fromJson(const {});

      expect(
        settings.followingListVisibility,
        FollowingListVisibility.everyone,
      );
      expect(settings.isPrivateAccount, isFalse);
    });

    test('parses persisted privacy settings', () {
      final settings = ProfilePrivacySettings.fromJson(const {
        'followingListVisibility': 'followers',
        'isPrivateAccount': true,
      });

      expect(
        settings.followingListVisibility,
        FollowingListVisibility.followers,
      );
      expect(settings.isPrivateAccount, isTrue);
    });
  });

  group('FollowingListVisibility.canBeViewedBy', () {
    test('always lets the owner view the list', () {
      for (final visibility in FollowingListVisibility.values) {
        expect(
          visibility.canBeViewedBy(isOwner: true, isFollower: false),
          isTrue,
        );
      }
    });

    test('enforces follower-only and owner-only modes', () {
      expect(
        FollowingListVisibility.followers.canBeViewedBy(
          isOwner: false,
          isFollower: true,
        ),
        isTrue,
      );
      expect(
        FollowingListVisibility.followers.canBeViewedBy(
          isOwner: false,
          isFollower: false,
        ),
        isFalse,
      );
      expect(
        FollowingListVisibility.onlyMe.canBeViewedBy(
          isOwner: false,
          isFollower: true,
        ),
        isFalse,
      );
    });
  });
}
