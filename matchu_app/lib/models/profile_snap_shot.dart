class ProfileSnapshot {
  final String fullname;
  final String nickname;
  final String gender;
  final DateTime birthday;
  final List<String> interests;

  ProfileSnapshot({
    required this.fullname,
    required this.nickname,
    required this.gender,
    required this.birthday,
    this.interests = const [],
  });
}
