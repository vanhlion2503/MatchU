import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/user_model.dart';

class BlockedUserModel {
  const BlockedUserModel({
    required this.blockedUserId,
    required this.displayName,
    required this.nickname,
    required this.avatarUrl,
    this.blockedAt,
  });

  final String blockedUserId;
  final String displayName;
  final String nickname;
  final String avatarUrl;
  final DateTime? blockedAt;

  String get title {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;

    final handle = nickname.trim();
    if (handle.isNotEmpty) return handle;

    return 'Ng\u01B0\u1EDDi d\u00F9ng';
  }

  String get handle => nickname.trim();

  factory BlockedUserModel.fromUser(UserModel user, {DateTime? blockedAt}) {
    return BlockedUserModel(
      blockedUserId: user.uid.trim(),
      displayName: user.fullname.trim(),
      nickname: user.nickname.trim(),
      avatarUrl: user.avatarUrl.trim(),
      blockedAt: blockedAt,
    );
  }

  factory BlockedUserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BlockedUserModel(
      blockedUserId: (data['blockedUserId'] ?? doc.id).toString().trim(),
      displayName: (data['displayName'] ?? '').toString(),
      nickname: (data['nickname'] ?? '').toString(),
      avatarUrl: (data['avatarUrl'] ?? '').toString(),
      blockedAt: _asDateTime(data['blockedAt']),
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
