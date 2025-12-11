import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullname;
  final String nickname;
  final String phonenumber;

  final String? googleId;                 // Đăng nhập Google
  final DateTime? birthday;
  final String? gender;
  final String bio;
  final String avatarUrl;

  final List<String> interests;           // Sở thích

  final double? lat;
  final double? lng;

  final bool nearlyEnabled;               
  final int reputationScore;              
  final int trustWarnings;                
  final int totalReports;                 

  final double avgChatRating;             
  final int totalChatRatings;             

  final List<String> followers;           // Danh sách người theo dõi
  final List<String> following;           // Danh sách mình theo dõi

  final int rank;                         
  final int experience;                   
  final int dailyExp;                     

  final int totalPosts;                   
  final int totalLikes;                   

  final String activeStatus;              
  final String accountStatus;             

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

    this.googleId,

    this.birthday,
    this.gender,
    this.bio = "",
    this.avatarUrl = "",

    this.interests = const [],

    this.lat,
    this.lng,

    this.nearlyEnabled = true,
    this.reputationScore = 100,
    this.trustWarnings = 0,
    this.totalReports = 0,

    this.avgChatRating = 5.0,
    this.totalChatRatings = 0,

    this.followers = const [],
    this.following = const [],

    this.rank = 1,
    this.experience = 0,
    this.dailyExp = 0,

    this.totalPosts = 0,
    this.totalLikes = 0,

    this.activeStatus = "offline",
    this.accountStatus = "active",

    this.role = "user",
    this.isProfileCompleted = false,

    this.lastActiveAt,
    this.createdAt,
    this.updatedAt,
  });

  /* ======================= toJson ======================= */

  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "email": email,
      "fullname": fullname,
      "nickname": nickname,
      "phonenumber": phonenumber,

      "googleId": googleId,

      "birthday": birthday?.toIso8601String(),
      "gender": gender,
      "bio": bio,
      "avatarUrl": avatarUrl,

      "interests": interests,

      "location": {
        "lat": lat,
        "lng": lng,
      },

      "nearlyEnabled": nearlyEnabled,
      "reputationScore": reputationScore,
      "trustWarnings": trustWarnings,
      "totalReports": totalReports,

      "avgChatRating": avgChatRating,
      "totalChatRatings": totalChatRatings,

      "followers": followers,
      "following": following,

      "rank": rank,
      "experience": experience,
      "dailyExp": dailyExp,

      "totalPosts": totalPosts,
      "totalLikes": totalLikes,

      "activeStatus": activeStatus,
      "accountStatus": accountStatus,

      "role": role,
      "isProfileCompleted": isProfileCompleted,

      "lastActiveAt": lastActiveAt?.toIso8601String(),
      "createdAt": createdAt?.toIso8601String(),
      "updatedAt": updatedAt?.toIso8601String(),
    };
  }

  /* ======================= fromJson ======================= */

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    final location = json["location"] as Map<String, dynamic>?;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return UserModel(
      uid: uid,
      email: json["email"] ?? "",
      fullname: json["fullname"] ?? "",
      nickname: json["nickname"] ?? "",
      phonenumber: json["phonenumber"] ?? "",

      googleId: json["googleId"],

      birthday: parseDate(json["birthday"]),
      gender: json["gender"],
      bio: json["bio"] ?? "",
      avatarUrl: json["avatarUrl"] ?? "",

      interests: List<String>.from(json["interests"] ?? []),

      lat: location?["lat"] != null ? (location!["lat"] as num).toDouble() : null,
      lng: location?["lng"] != null ? (location!["lng"] as num).toDouble() : null,

      nearlyEnabled: json["nearlyEnabled"] ?? true,
      reputationScore: json["reputationScore"] ?? 100,
      trustWarnings: json["trustWarnings"] ?? 0,
      totalReports: json["totalReports"] ?? 0,

      avgChatRating: (json["avgChatRating"] ?? 5.0).toDouble(),
      totalChatRatings: json["totalChatRatings"] ?? 0,

      followers: List<String>.from(json["followers"] ?? []),
      following: List<String>.from(json["following"] ?? []),

      rank: json["rank"] ?? 1,
      experience: json["experience"] ?? 0,
      dailyExp: json["dailyExp"] ?? 0,

      totalPosts: json["totalPosts"] ?? 0,
      totalLikes: json["totalLikes"] ?? 0,

      activeStatus: json["activeStatus"] ?? "offline",
      accountStatus: json["accountStatus"] ?? "active",

      role: json["role"] ?? "user",
      isProfileCompleted: json["isProfileCompleted"] ?? false,

      lastActiveAt: parseDate(json["lastActiveAt"]),
      createdAt: parseDate(json["createdAt"]),
      updatedAt: parseDate(json["updatedAt"]),
    );
  }

  /* ======================= copyWith ======================= */

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullname,
    String? nickname,
    String? phonenumber,

    String? googleId,

    DateTime? birthday,
    String? gender,
    String? bio,
    String? avatarUrl,

    List<String>? interests,

    double? lat,
    double? lng,

    bool? nearlyEnabled,
    int? reputationScore,
    int? trustWarnings,
    int? totalReports,

    double? avgChatRating,
    int? totalChatRatings,

    List<String>? followers,
    List<String>? following,

    int? rank,
    int? experience,
    int? dailyExp,

    int? totalPosts,
    int? totalLikes,

    String? activeStatus,
    String? accountStatus,

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

      googleId: googleId ?? this.googleId,

      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,

      interests: interests ?? this.interests,

      lat: lat ?? this.lat,
      lng: lng ?? this.lng,

      nearlyEnabled: nearlyEnabled ?? this.nearlyEnabled,
      reputationScore: reputationScore ?? this.reputationScore,
      trustWarnings: trustWarnings ?? this.trustWarnings,
      totalReports: totalReports ?? this.totalReports,

      avgChatRating: avgChatRating ?? this.avgChatRating,
      totalChatRatings: totalChatRatings ?? this.totalChatRatings,

      followers: followers ?? this.followers,
      following: following ?? this.following,

      rank: rank ?? this.rank,
      experience: experience ?? this.experience,
      dailyExp: dailyExp ?? this.dailyExp,

      totalPosts: totalPosts ?? this.totalPosts,
      totalLikes: totalLikes ?? this.totalLikes,

      activeStatus: activeStatus ?? this.activeStatus,
      accountStatus: accountStatus ?? this.accountStatus,

      role: role ?? this.role,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,

      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
