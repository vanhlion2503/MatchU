import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final String lastMessageType;
  final String? lastMessageCipher;
  final String? lastMessageIv;
  final int lastMessageKeyId;
  final DateTime? lastMessageAt;
  final Map<String, dynamic>? unread;
  final Map<String, dynamic>? pinned;
  final Map<String, dynamic>? deletedFor;
  final Map<String, dynamic>? clearedAt;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastSenderId,
    this.lastMessageType = '',
    this.lastMessageCipher,
    this.lastMessageIv,
    this.lastMessageKeyId = 0,
    this.lastMessageAt,
    this.unread,
    this.pinned,
    this.deletedFor,
    this.clearedAt,
  });

  factory ChatRoomModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data["participants"]),
      lastMessage: data["lastMessage"] ?? "",
      lastSenderId: data["lastSenderId"] ?? "",
      lastMessageType: (data["lastMessageType"] ?? "").toString(),
      lastMessageCipher: data["lastMessageCipher"],
      lastMessageIv: data["lastMessageIv"],
      lastMessageKeyId: (data["lastMessageKeyId"] ?? 0) as int,
      lastMessageAt: (data["lastMessageAt"] as Timestamp?)?.toDate(),
      unread: data["unread"],
      pinned: data["pinned"],
      deletedFor: data["deletedFor"],
      clearedAt: data["clearedAt"],
    );
  }

  bool isPinned(String uid) => pinned?[uid] == true;
  bool isDeletedFor(String uid) => deletedFor?[uid] == true;

  DateTime? clearedAtFor(String uid) {
    final value = clearedAt?[uid];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int unreadCount(String uid) {
    final value = unread?[uid];
    return value is num ? value.toInt() : 0;
  }
}
