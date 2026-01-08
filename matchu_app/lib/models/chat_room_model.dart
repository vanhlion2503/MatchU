import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final String? lastMessageCipher;
  final String? lastMessageIv;
  final DateTime? lastMessageAt;
  final Map<String, dynamic>? unread;
  final Map<String, dynamic>? pinned;
  final Map<String, dynamic>? deletedFor;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastSenderId,
    this.lastMessageCipher,
    this.lastMessageIv,
    this.lastMessageAt,
    this.unread,
    this.pinned,
    this.deletedFor,
  });

  factory ChatRoomModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data["participants"]),
      lastMessage: data["lastMessage"] ?? "",
      lastSenderId: data["lastSenderId"] ?? "",
      lastMessageCipher: data["lastMessageCipher"],
      lastMessageIv: data["lastMessageIv"],
      lastMessageAt: (data["lastMessageAt"] as Timestamp?)?.toDate(),
      unread: data["unread"],
      pinned: data["pinned"],
      deletedFor: data["deletedFor"],
    );
  }

  bool isPinned(String uid) => pinned?[uid] == true;
  bool isDeletedFor(String uid) => deletedFor?[uid] == true;

  int unreadCount(String uid) => unread?[uid] ?? 0;
}

