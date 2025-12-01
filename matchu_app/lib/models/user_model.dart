class UserModel {
  final String uid;
  final String fullname;
  final String nickname;
  final String phonenumber;
  final DateTime? birthday;
  final String? gender;
  final String? bio;
  final String? avatarUrl;
  final double? lat;
  final double? lng;
  final bool nearlyEnabled;
  final int reputationScore;
  final int followersCount;
  final int followingCount;
  final String activeStatus;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.fullname,
    required this.nickname,
    required this.phonenumber,
    this.birthday,
    this.gender,
    this.bio,
    this.avatarUrl,
    this.lat,
    this.lng,
    this.nearlyEnabled = true,
    this.reputationScore = 100,
    this.followersCount = 0,
    this.followingCount = 0,
    this.activeStatus = 'offline',
    this.createdAt,
  });

  Map<String, dynamic> toJson(){
    return {
      'uid' : uid,
      'fullname' : fullname,
      'nickname' : nickname,
      'phonenumber' : phonenumber,
      'birthday': birthday?.toIso8601String(),
      'gender': gender,
      'bio' : bio,
      'avatarUrl': avatarUrl,
      'location': {
        'lat': lat,
        'lng': lng,
      },
      'nearlyEnabled': nearlyEnabled,
      'reputationScore': reputationScore,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'activeStatus': activeStatus,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    final location = json['location'] as Map<String, dynamic>?;

    return UserModel(
      uid: uid,
      fullname: json['name'] ?? '',
      nickname: json['nickname'] ?? '',
      phonenumber: json['phoneNumber'] ?? '', 
      birthday: json['birthday'] != null
          ? DateTime.tryParse(json['birthday'])
          : null,
      gender: json['gender'],
      bio: json['bio'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      lat: location?['lat'] != null
          ? (location?['lat'] as num).toDouble()
          : null,
      lng: location?['lng'] != null
          ? (location?['lng'] as num).toDouble()
          : null,
      nearlyEnabled: json['nearlyEnabled'] ?? true,
      reputationScore: json['reputationScore'] ?? 0,
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      activeStatus: json['activeStatus'] ?? 'offline',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.tryParse(json['createdAt'])
              : null)
          : null,
    );
  }
  UserModel copyWith({
    String? uid,
    String? fullname,
    String? nickname,
    String? phonenumber,
    DateTime? birthday,
    String? gender,
    String? bio,
    String? avatarUrl,
    double? lat,
    double? lng,
    bool? nearlyEnabled,
    int? reputationScore,
    int? followersCount,
    int? followingCount,
    String? activeStatus,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullname: fullname ?? this.fullname,
      nickname: nickname ?? this.nickname,
      phonenumber: phonenumber ?? this.phonenumber,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      nearlyEnabled: nearlyEnabled ?? this.nearlyEnabled,
      reputationScore: reputationScore ?? this.reputationScore,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      activeStatus: activeStatus ?? this.activeStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}