import 'package:cloud_firestore/cloud_firestore.dart';

class MutedNotificationAuthorModel {
  const MutedNotificationAuthorModel({
    required this.authorId,
    required this.displayName,
    required this.nickname,
    required this.avatarUrl,
    required this.sourceNotificationId,
    this.mutedAt,
  });

  final String authorId;
  final String displayName;
  final String nickname;
  final String avatarUrl;
  final String sourceNotificationId;
  final DateTime? mutedAt;

  String get title {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;

    final handle = nickname.trim();
    if (handle.isNotEmpty) return handle;

    return 'Ng\u01B0\u1EDDi d\u00F9ng';
  }

  String get handle => nickname.trim();

  factory MutedNotificationAuthorModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MutedNotificationAuthorModel(
      authorId: (data['authorId'] ?? doc.id).toString().trim(),
      displayName: (data['displayName'] ?? '').toString(),
      nickname: (data['nickname'] ?? '').toString(),
      avatarUrl: (data['avatarUrl'] ?? '').toString(),
      sourceNotificationId: (data['sourceNotificationId'] ?? '').toString(),
      mutedAt: _asDateTime(data['mutedAt']),
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
