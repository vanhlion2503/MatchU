import 'package:cloud_firestore/cloud_firestore.dart';

class TempChatRoomModel {
  const TempChatRoomModel({
    required this.roomId,
    required this.userA,
    required this.userB,
    required this.participants,
    required this.createdAt,
    required this.expiresAt,
    this.userALiked,
    this.userBLiked,
    this.status = 'active',
    this.anonymousAvatars = const {},
    this.permanentRoomId,
  });

  final String roomId;
  final String userA;
  final String userB;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool? userALiked;
  final bool? userBLiked;
  final Map<String, String> anonymousAvatars;
  final String status;
  final String? permanentRoomId;

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'userA': userA,
    'userB': userB,
    'participants': participants,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'userALiked': userALiked,
    'userBLiked': userBLiked,
    'anonymousAvatars': anonymousAvatars,
    'status': status,
    'permanentRoomId': permanentRoomId,
  };

  factory TempChatRoomModel.fromJson(Map<String, dynamic> json) {
    final createdAt = _readDate(json['createdAt']) ?? DateTime.now();
    // `expireAt` is accepted for rooms created by the legacy client.
    final expiresAt =
        _readDate(json['expiresAt']) ??
        _readDate(json['expireAt']) ??
        createdAt.add(const Duration(minutes: 7));

    return TempChatRoomModel(
      roomId: json['roomId']?.toString() ?? '',
      userA: json['userA']?.toString() ?? '',
      userB: json['userB']?.toString() ?? '',
      participants: List<String>.from(json['participants'] ?? const []),
      createdAt: createdAt,
      expiresAt: expiresAt,
      userALiked: json['userALiked'] as bool?,
      userBLiked: json['userBLiked'] as bool?,
      status: json['status']?.toString() ?? 'active',
      anonymousAvatars: Map<String, String>.from(
        json['anonymousAvatars'] ?? const {},
      ),
      permanentRoomId: json['permanentRoomId']?.toString(),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
