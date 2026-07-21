import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMuteSetting {
  const ChatMuteSetting({required this.userId, this.mutedUntil});

  final String userId;

  /// `null` means notifications stay muted until the user turns them on again.
  final DateTime? mutedUntil;

  bool isActiveAt(DateTime now) {
    return mutedUntil == null || mutedUntil!.isAfter(now);
  }

  factory ChatMuteSetting.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawMutedUntil = data['mutedUntil'];

    return ChatMuteSetting(
      userId: (data['mutedUserId'] ?? doc.id).toString().trim(),
      mutedUntil:
          rawMutedUntil is Timestamp
              ? rawMutedUntil.toDate()
              : rawMutedUntil is DateTime
              ? rawMutedUntil
              : null,
    );
  }
}
