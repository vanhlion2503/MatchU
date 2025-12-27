import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageAt;
  final Map<String, int> unread;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.unread,
  });

  factory ChatRoomModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data["participants"] ?? []),
      lastMessage: data["lastMessage"] ?? "",
      lastSenderId: data["lastSenderId"] ?? "",
      lastMessageAt:
          (data["lastMessageAt"] as Timestamp?)?.toDate(),
      unread: Map<String, int>.from(data["unread"] ?? {}),
    );
  }

  /// 👉 Lấy UID của người còn lại
  String otherUid(String myUid) {
    return participants.firstWhere((e) => e != myUid);
  }

  int unreadCount(String myUid) {
    return unread[myUid] ?? 0;
  }
}
