class NearbyUserVM {
  final String uid;
  final String fullname;
  final String nickname;
  final String avatarUrl;
  final double distanceKm;
  final String activeStatus;
  final bool isFaceVerified;

  NearbyUserVM({
    required this.uid,
    required this.fullname,
    required this.nickname,
    required this.avatarUrl,
    required this.distanceKm,
    required this.activeStatus,
    required this.isFaceVerified,
  });
}
