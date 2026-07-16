import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';

/// Repository for temp-room state and message operations.
///
/// Matching and permanent-room conversion are server-authoritative. Frequent
/// room operations stay on Firestore so snapshots retain offline/optimistic UI.
class TempChatService {
  TempChatService({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _db = db ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final Map<String, String> _typingKeyCache = {};

  static const Map<String, dynamic> _approvedSystemFields = {
    'status': 'approved',
    'blockedBy': null,
    'reason': null,
    'warning': false,
    'aiScore': null,
  };

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) {
    return _db.collection('tempChats').doc(roomId);
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String roomId) {
    return _roomRef(roomId).collection('messages');
  }

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    final snapshot = await _roomRef(roomId).get();
    final data = snapshot.data();
    if (data == null) throw StateError('Temp room not found: $roomId');
    return data;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _roomRef(roomId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessages(String roomId) {
    return _messagesRef(
      roomId,
    ).orderBy('createdAt').limitToLast(80).snapshots();
  }

  Future<void> sendMessages(String roomId, TempMessageModel message) async {
    await _messagesRef(roomId).add(message.toJson());
  }

  Future<void> setLike({
    required String roomId,
    required String uid,
    required bool value,
  }) async {
    final roomRef = _roomRef(roomId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final room = snapshot.data();
      if (room == null || room['status'] != 'active') return;

      final userA = room['userA'];
      final userB = room['userB'];
      if (userA is! String || userB is! String) return;
      if (uid != userA && uid != userB) return;

      final isA = userA == uid;
      final otherUid = isA ? userB : userA;
      final field = isA ? 'userALiked' : 'userBLiked';
      if (room[field] == value) return;

      transaction.update(roomRef, {field: value});
      if (value) {
        transaction.set(_messagesRef(roomId).doc(), {
          'type': 'system',
          'systemCode': 'like',
          'text': '❤️ Đối phương đã thích bạn',
          'senderId': uid,
          'targetUid': otherUid,
          ..._approvedSystemFields,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> endRoom({
    required String roomId,
    required String uid,
    required String reason,
  }) async {
    final roomRef = _roomRef(roomId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final room = snapshot.data();
      if (room == null || room['status'] != 'active') return;
      final participants = List<String>.from(room['participants'] ?? const []);
      if (!participants.contains(uid)) return;

      transaction.update(roomRef, {
        'status': 'ended',
        'endedBy': uid,
        'endedReason': reason,
        'endedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(_messagesRef(roomId).doc(), {
        'type': 'system',
        'event': 'ended',
        'text':
            reason == 'left'
                ? 'Người kia đã rời phòng'
                : 'Cuộc trò chuyện đã kết thúc',
        'senderId': uid,
        ..._approvedSystemFields,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> convertToPermanent(String tempRoomId) async {
    final result = await _functions.httpsCallable('convertTempChat').call({
      'roomId': tempRoomId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final roomId = data['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) {
      throw StateError('Permanent room was not created');
    }
    return roomId;
  }

  Future<void> sendSystemMessage({
    required String roomId,
    required String text,
    required String code,
    required String senderId,
  }) async {
    await _messagesRef(roomId).add({
      'type': 'system',
      'systemCode': code,
      'text': text,
      'senderId': senderId,
      ..._approvedSystemFields,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _resolveTypingField({
    required String roomId,
    required String uid,
  }) async {
    final cached = _typingKeyCache[roomId];
    if (cached != null) return cached;

    final snapshot = await _roomRef(roomId).get();
    final room = snapshot.data();
    if (room == null) return null;
    final userA = room['userA'];
    final userB = room['userB'];
    final field = userA == uid ? 'userA' : (userB == uid ? 'userB' : null);
    if (field != null) _typingKeyCache[roomId] = field;
    return field;
  }

  Future<void> setTyping({
    required String roomId,
    required String uid,
    required bool typing,
  }) async {
    final field = await _resolveTypingField(roomId: roomId, uid: uid);
    if (field == null) return;
    await _roomRef(roomId).update({'typing.$field': typing});
  }

  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String uid,
    required String reactionId,
  }) async {
    final messageRef = _messagesRef(roomId).doc(messageId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(messageRef);
      final message = snapshot.data();
      if (message == null || message['status'] != 'approved') return;

      final reactions = Map<String, dynamic>.from(
        message['reactions'] ?? const {},
      );
      transaction.update(messageRef, {
        'reactions.$uid':
            reactions[uid] == reactionId ? FieldValue.delete() : reactionId,
      });
    });
  }
}
