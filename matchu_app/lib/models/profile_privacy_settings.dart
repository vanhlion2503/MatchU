enum FollowingListVisibility {
  everyone('everyone'),
  followers('followers'),
  onlyMe('only_me');

  const FollowingListVisibility(this.firestoreValue);

  final String firestoreValue;

  static FollowingListVisibility fromFirestore(dynamic value) {
    return FollowingListVisibility.values.firstWhere(
      (item) => item.firestoreValue == value,
      orElse: () => FollowingListVisibility.everyone,
    );
  }

  bool canBeViewedBy({required bool isOwner, required bool isFollower}) {
    if (isOwner) return true;
    return switch (this) {
      FollowingListVisibility.everyone => true,
      FollowingListVisibility.followers => isFollower,
      FollowingListVisibility.onlyMe => false,
    };
  }
}

class ProfilePrivacySettings {
  const ProfilePrivacySettings({
    this.followingListVisibility = FollowingListVisibility.everyone,
    this.isPrivateAccount = false,
  });

  final FollowingListVisibility followingListVisibility;
  final bool isPrivateAccount;

  factory ProfilePrivacySettings.fromJson(Map<String, dynamic>? json) {
    return ProfilePrivacySettings(
      followingListVisibility: FollowingListVisibility.fromFirestore(
        json?['followingListVisibility'],
      ),
      isPrivateAccount: json?['isPrivateAccount'] == true,
    );
  }
}
