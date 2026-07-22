import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';

/// Data contract for a temporary chat session.
abstract class TempChatRepository {
  Future<Map<String, dynamic>> getRoom(String roomId);
  Future<ChatPeerSummary?> getPeerSummary(String uid);
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId);
  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessages(String roomId);
  Stream<QuerySnapshot<Map<String, dynamic>>> listenTyping(String roomId);
  Future<String> sendMessages(String roomId, TempMessageModel message);

  Future<void> setLike({
    required String roomId,
    required String uid,
    required bool value,
  });

  Future<void> endRoom({
    required String roomId,
    required String uid,
    required String reason,
  });

  Future<String> convertToPermanent(String tempRoomId);

  Future<void> sendSystemMessage({
    required String roomId,
    required String text,
    required String code,
    required String senderId,
  });

  Future<void> setTyping({
    required String roomId,
    required String uid,
    required bool typing,
  });

  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String uid,
    required String reactionId,
  });
}
