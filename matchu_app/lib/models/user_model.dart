import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullname;
  final String nickname;
  final String phonenumber;

  final DateTime? birthday;
  final String? gender;
  final String bio;
  final String avatarUrl;

  final double? lat;
  final double? lng;

  final bool nearlyEnabled;
  final int reputationScore;
  final int followersCount;
  final int followingCount;
  final String activeStatus;

  final String role;
  final bool isProfileCompleted;

  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullname,
    required this.nickname,
    required this.phonenumber,

    this.birthday,
    this.gender,
    this.bio = '',
    this.avatarUrl = '',

    this.lat,
    this.lng,

    this.nearlyEnabled = true,
    this.reputationScore = 100,
    this.followersCount = 0,
    this.followingCount = 0,
    this.activeStatus = 'offline',

    this.role = 'user',
    this.isProfileCompleted = false,

    this.lastActiveAt,
    this.createdAt,
    this.updatedAt,
  });

  /* ======================= toJson ======================= */

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullname': fullname,
      'nickname': nickname,
      'phonenumber': phonenumber,

      'birthday': birthday?.toIso8601String(),
      'gender': gender,
      'bio': bio,
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

      'role': role,
      'isProfileCompleted': isProfileCompleted,

      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /* ======================= fromJson ======================= */

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    final location = json['location'] as Map<String, dynamic>?;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return UserModel(
      uid: uid,
      email: json['email'] ?? '',

      fullname: json['fullname'] ?? '',
      nickname: json['nickname'] ?? '',
      phonenumber: json['phonenumber'] ?? '',

      birthday: parseDate(json['birthday']),
      gender: json['gender'],
      bio: json['bio'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',

      lat: location?['lat'] != null
          ? (location!['lat'] as num).toDouble()
          : null,
      lng: location?['lng'] != null
          ? (location!['lng'] as num).toDouble()
          : null,

      nearlyEnabled: json['nearlyEnabled'] ?? true,
      reputationScore: json['reputationScore'] ?? 100,
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      activeStatus: json['activeStatus'] ?? 'offline',

      role: json['role'] ?? 'user',
      isProfileCompleted: json['isProfileCompleted'] ?? false,

      lastActiveAt: parseDate(json['lastActiveAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  /* ======================= copyWith ======================= */

  UserModel copyWith({
    String? uid,
    String? email,
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

    String? role,
    bool? isProfileCompleted,

    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
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

      role: role ?? this.role,
      isProfileCompleted:
          isProfileCompleted ?? this.isProfileCompleted,

      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
