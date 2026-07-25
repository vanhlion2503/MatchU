import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';
import 'package:matchu_app/models/temp_room_extension.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';
import 'package:matchu_app/repositories/chat/temp_chat_repository.dart';

/// Repository for temp-room state and message operations.
///
/// Matching and permanent-room conversion are server-authoritative. Frequent
/// room operations stay on Firestore so snapshots retain offline/optimistic UI.
class TempChatService implements TempChatRepository {
  TempChatService({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _db = db ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

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

  @override
  Future<Map<String, dynamic>> getRoom(String roomId) async {
    final snapshot = await _roomRef(roomId).get();
    final data = snapshot.data();
    if (data == null) throw StateError('Temp room not found: $roomId');
    return data;
  }

  @override
  Future<ChatPeerSummary?> getPeerSummary(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    final data = snapshot.data();
    return data == null ? null : ChatPeerSummary.fromMap(data);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _roomRef(roomId).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessages(String roomId) {
    return _messagesRef(
      roomId,
    ).orderBy('createdAt').limitToLast(80).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> listenTyping(String roomId) {
    return _roomRef(roomId).collection('presence').snapshots();
  }

  @override
  Future<String> sendMessages(String roomId, TempMessageModel message) async {
    final messageRef = _messagesRef(roomId).doc(message.id);
    await messageRef.set(message.toJson());
    return messageRef.id;
  }

  @override
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

  @override
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

      // A timeout raced with a successful extension. Re-reading expiresAt in
      // this transaction prevents the stale client clock from ending the room.
      if (reason == 'timeout') {
        final expiresAt = room['expiresAt'];
        if (expiresAt is Timestamp &&
            expiresAt.toDate().isAfter(DateTime.now())) {
          return;
        }
      }

      final userA = room['userA'];
      final userB = room['userB'];
      if (userA is! String || userB is! String) return;

      // Leaving used to require a separate setLike transaction before this
      // transaction. Telepathy can update the same room at that moment, making
      // both transactions retry and keeping the UI waiting. Persist the
      // implicit dislike together with the terminal room state instead.
      final likeField = userA == uid ? 'userALiked' : 'userBLiked';

      transaction.update(roomRef, {
        'status': 'ended',
        'endedBy': uid,
        'endedReason': reason,
        'endedAt': FieldValue.serverTimestamp(),
        if (reason == 'left' && room[likeField] == null) likeField: false,
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

  @override
  Future<void> extendRoom(String roomId) async {
    try {
      await _functions.httpsCallable('extendTempChatRoom').call({
        'roomId': roomId,
      });
    } on FirebaseFunctionsException catch (error) {
      final details =
          error.details is Map
              ? Map<String, dynamic>.from(error.details as Map)
              : const <String, dynamic>{};
      final reason = details['reason']?.toString();
      final failure = switch (reason) {
        'insufficient-gem' => TempRoomExtensionFailure.insufficientGem,
        'too-early' => TempRoomExtensionFailure.tooEarly,
        'room-expired' => TempRoomExtensionFailure.expired,
        'extension-limit-reached' => TempRoomExtensionFailure.limitReached,
        'room-not-active' ||
        'not-participant' ||
        'mutual-consent-complete' => TempRoomExtensionFailure.roomUnavailable,
        _ => TempRoomExtensionFailure.unknown,
      };
      final rawGem = details['currentGem'];
      throw TempRoomExtensionException(
        failure,
        currentGem: rawGem is num ? rawGem.toInt() : null,
      );
    }
  }

  @override
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

  @override
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

  @override
  Future<void> setTyping({
    required String roomId,
    required String uid,
    required bool typing,
  }) async {
    final now = DateTime.now();
    await _roomRef(roomId).collection('presence').doc(uid).set({
      'uid': uid,
      'isTyping': typing,
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 10))),
    });
  }

  @override
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
