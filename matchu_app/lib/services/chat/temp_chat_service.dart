import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';

class TempChatService {
  TempChatService({
    FirebaseFirestore? db,
    PostRestrictionService? restrictionService,
  }) : _db = db ?? FirebaseFirestore.instance,
       _restrictionService = restrictionService ?? PostRestrictionService();

  final FirebaseFirestore _db;
  final PostRestrictionService _restrictionService;
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
    final snap = await _roomRef(roomId).get();
    final data = snap.data();
    if (data == null) {
      throw StateError('Temp room not found: $roomId');
    }
    return data;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _roomRef(roomId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessages(String roomId) {
    return _messagesRef(roomId).orderBy('createdAt').snapshots();
  }

  Future<void> sendMessages(String roomId, TempMessageModel messages) async {
    await _ensureCanInteract(roomId, messages.senderId);
    await _messagesRef(roomId).add(messages.toJson());
  }

  Future<void> setLike({
    required String roomId,
    required String uid,
    required bool value,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final userA = data['userA'];
      final userB = data['userB'];
      if (userA is! String || userB is! String) return;

      final isA = userA == uid;
      final otherUid = isA ? userB : userA;
      final likeField = isA ? 'userALiked' : 'userBLiked';
      final previous = data[likeField] == true;

      // No state change => no write (prevents duplicate system messages).
      if (previous == value) return;

      tx.update(ref, {likeField: value});

      if (value == true) {
        tx.set(_messagesRef(roomId).doc(), {
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
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      if (data['status'] != 'active') return;

      tx.update(ref, {
        'status': 'ended',
        'endedBy': uid,
        'endedReason': reason,
        'endedAt': FieldValue.serverTimestamp(),
      });

      tx.set(_messagesRef(roomId).doc(), {
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
    final tempRef = _roomRef(tempRoomId);
    await _ensurePermanentConversionAllowed(tempRoomId);

    return _db.runTransaction<String>((tx) async {
      final tempSnap = await tx.get(tempRef);
      if (!tempSnap.exists) {
        throw StateError('Temp room not found');
      }

      final data = tempSnap.data() ?? const <String, dynamic>{};
      final participants = List<String>.from(data['participants'] ?? const []);
      if (participants.isEmpty) {
        throw StateError('Temp room has no participants');
      }

      if (data['status'] == 'converted' && data['permanentRoomId'] != null) {
        return data['permanentRoomId'] as String;
      }

      final newRoomRef = _db.collection('chatRooms').doc();

      tx.set(newRoomRef, {
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'fromTempRoom': tempRoomId,
        'e2ee': true,
        'lastMessage': '💬 Bắt đầu trò chuyện',
        'lastMessageType': 'system',
        'lastSenderId': null,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unread': {for (final uid in participants) uid: 0},
      });

      tx.update(tempRef, {
        'status': 'converted',
        'permanentRoomId': newRoomRef.id,
      });

      return newRoomRef.id;
    });
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

  Future<void> _ensureCanInteract(String roomId, String senderId) async {
    final snap = await _roomRef(roomId).get();
    final data = snap.data();
    if (data == null) return;

    final otherUid = _otherParticipant(data, senderId);
    if (otherUid == null) return;

    if (await _restrictionService.hasBlockRelationship(otherUid)) {
      throw StateError(
        'Kh\u00F4ng th\u1EC3 nh\u1EAFn tin v\u00EC m\u1ED9t trong hai ng\u01B0\u1EDDi \u0111\u00E3 ch\u1EB7n ng\u01B0\u1EDDi c\u00F2n l\u1EA1i.',
      );
    }
  }

  Future<void> _ensurePermanentConversionAllowed(String roomId) async {
    final data = await getRoom(roomId);
    final participants = List<String>.from(data['participants'] ?? const []);
    final currentUid = _restrictionService.uid;
    if (currentUid.isEmpty) return;

    final otherUid = participants.firstWhere(
      (participant) => participant.trim() != currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return;

    if (await _restrictionService.hasBlockRelationship(otherUid)) {
      throw StateError(
        'Kh\u00F4ng th\u1EC3 chuy\u1EC3n sang chat d\u00E0i v\u00EC m\u1ED9t trong hai ng\u01B0\u1EDDi \u0111\u00E3 ch\u1EB7n ng\u01B0\u1EDDi c\u00F2n l\u1EA1i.',
      );
    }
  }

  String? _otherParticipant(Map<String, dynamic> roomData, String senderId) {
    final participants = List<String>.from(
      roomData['participants'] ?? const [],
    );
    final normalizedSenderId = senderId.trim();
    if (normalizedSenderId.isEmpty) return null;

    final otherUid =
        participants
            .firstWhere(
              (participant) => participant.trim() != normalizedSenderId,
              orElse: () => '',
            )
            .trim();

    return otherUid.isEmpty ? null : otherUid;
  }

  Future<String?> _resolveTypingField({
    required String roomId,
    required String uid,
  }) async {
    final cached = _typingKeyCache[roomId];
    if (cached != null) return cached;

    final snap = await _roomRef(roomId).get();
    final data = snap.data();
    if (data == null) return null;

    final userA = data['userA'];
    final userB = data['userB'];
    if (userA is! String || userB is! String) return null;

    final key = userA == uid ? 'userA' : (userB == uid ? 'userB' : null);
    if (key != null) {
      _typingKeyCache[roomId] = key;
    }
    return key;
  }

  Future<void> setTyping({
    required String roomId,
    required String uid,
    required bool typing,
  }) async {
    final typingKey = await _resolveTypingField(roomId: roomId, uid: uid);
    if (typingKey == null) return;
    await _roomRef(roomId).update({'typing.$typingKey': typing});
  }

  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String uid,
    required String reactionId,
  }) async {
    final msgRef = _messagesRef(roomId).doc(messageId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(msgRef);
      final data = snap.data();
      if (data == null) return;

      final reactions = Map<String, dynamic>.from(
        data['reactions'] ?? const {},
      );
      final current = reactions[uid];

      if (current == reactionId) {
        tx.update(msgRef, {'reactions.$uid': FieldValue.delete()});
      } else {
        tx.update(msgRef, {'reactions.$uid': reactionId});
      }
    });
  }
}
