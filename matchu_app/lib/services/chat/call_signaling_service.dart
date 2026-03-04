import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallSignalingService {
  CallSignalingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _calls =>
      _firestore.collection('callSessions');

  Future<String> createCallDocument({
    required String roomChatId,
    required String callerId,
    required String receiverId,
    required String type,
    required Map<String, dynamic> offer,
  }) async {
    final callRef = _calls.doc();

    await callRef.set({
      'callId': callRef.id,
      'roomChatId': roomChatId,
      'callerId': callerId,
      'receiverId': receiverId,
      'participants': [callerId, receiverId],
      'type': type,
      'status': 'ringing',
      'offer': offer,
      'answer': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return callRef.id;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCallDocument(
    String callId,
  ) async {
    return _calls.doc(callId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenCallDocument(
    String callId,
  ) {
    return _calls.doc(callId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenIncomingCall(String uid) {
    return _calls
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  Future<void> updateOffer({
    required String callId,
    required Map<String, dynamic> offer,
  }) async {
    await _calls.doc(callId).set({
      'offer': offer,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateAnswer({
    required String callId,
    required Map<String, dynamic> answer,
  }) async {
    await _calls.doc(callId).set({
      'answer': answer,
      'status': 'active',
      'answeredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> rejectCall(String callId, {String reason = 'rejected'}) async {
    await _calls.doc(callId).set({
      'status': reason,
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> endCall(String callId) async {
    await _calls.doc(callId).set({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> persistCallSummaryMessage({
    required String callId,
    String? fallbackRoomChatId,
    String? fallbackCallerId,
    String? fallbackReceiverId,
    String? fallbackType,
    String? fallbackStatus,
    int fallbackDurationSeconds = 0,
  }) async {
    final callRef = _calls.doc(callId);

    await _firestore.runTransaction((transaction) async {
      final callSnap = await transaction.get(callRef);
      final callData = callSnap.data() ?? <String, dynamic>{};

      final roomChatId =
          _asString(callData['roomChatId']) ?? (fallbackRoomChatId ?? '');
      final callerId =
          _asString(callData['callerId']) ?? (fallbackCallerId ?? '');
      final receiverId =
          _asString(callData['receiverId']) ?? (fallbackReceiverId ?? '');

      if (roomChatId.isEmpty || callerId.isEmpty || receiverId.isEmpty) {
        return;
      }

      final status = _resolveTerminalCallStatus(
        primaryStatus: _asString(callData['status']),
        fallbackStatus: fallbackStatus,
      );
      if (status == null) {
        return;
      }

      final callType = _normalizeCallType(
        _asString(callData['type']) ?? fallbackType,
      );
      final answeredAt = _asTimestamp(callData['answeredAt']);
      final endedAt = _asTimestamp(callData['endedAt']);

      final durationSeconds =
          status == 'ended'
              ? _resolveDurationSeconds(
                answeredAt: answeredAt,
                endedAt: endedAt,
                fallbackDurationSeconds: fallbackDurationSeconds,
              )
              : 0;
      final messageText = _buildCallSummaryText(
        status: status,
        callType: callType,
        durationSeconds: durationSeconds,
      );
      final createdAtValue = endedAt ?? FieldValue.serverTimestamp();

      final roomRef = _firestore.collection('chatRooms').doc(roomChatId);
      final roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists) return;

      final messageRef = roomRef.collection('messages').doc('call_$callId');
      final messageSnap = await transaction.get(messageRef);
      if (messageSnap.exists) {
        return;
      }

      transaction.set(messageRef, {
        'senderId': callerId,
        'text': messageText,
        'type': 'call',
        'callData': {
          'callId': callId,
          'status': status,
          'callType': callType,
          'durationSeconds': durationSeconds,
        },
        'createdAt': createdAtValue,
      });

      transaction.update(roomRef, {
        'lastMessage': messageText,
        'lastMessageType': 'call',
        'lastMessageCipher': FieldValue.delete(),
        'lastMessageIv': FieldValue.delete(),
        'lastMessageKeyId': 0,
        'lastSenderId': callerId,
        'lastMessageAt': createdAtValue,
        'deletedFor.$callerId': FieldValue.delete(),
        'deletedFor.$receiverId': FieldValue.delete(),
        'unread.$receiverId': FieldValue.increment(1),
        'unread.$callerId': 0,
      });
    });
  }

  Future<void> addIceCandidate({
    required String callId,
    required bool isCaller,
    required String senderId,
    required RTCIceCandidate candidate,
  }) async {
    final collectionName = isCaller ? 'callerCandidates' : 'calleeCandidates';

    await _calls.doc(callId).collection(collectionName).add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'senderId': senderId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenRemoteIceCandidates({
    required String callId,
    required bool isCaller,
  }) {
    final remoteCollection = isCaller ? 'calleeCandidates' : 'callerCandidates';
    return _calls
        .doc(callId)
        .collection(remoteCollection)
        .orderBy('createdAt')
        .snapshots();
  }

  String? _resolveTerminalCallStatus({
    required String? primaryStatus,
    required String? fallbackStatus,
  }) {
    final normalizedPrimary = _normalizeCallStatus(primaryStatus);
    if (normalizedPrimary != null) {
      return normalizedPrimary;
    }

    return _normalizeCallStatus(fallbackStatus);
  }

  String? _normalizeCallStatus(String? status) {
    switch (status) {
      case 'ended':
      case 'rejected':
      case 'busy':
      case 'missed':
        return status;
      default:
        return null;
    }
  }

  String _normalizeCallType(String? type) {
    return type == 'video' ? 'video' : 'audio';
  }

  int _resolveDurationSeconds({
    required Timestamp? answeredAt,
    required Timestamp? endedAt,
    required int fallbackDurationSeconds,
  }) {
    if (answeredAt != null && endedAt != null) {
      final diff = endedAt.toDate().difference(answeredAt.toDate()).inSeconds;
      if (diff > 0) {
        return diff;
      }
    }
    if (fallbackDurationSeconds > 0) {
      return fallbackDurationSeconds;
    }
    return 0;
  }

  String _buildCallSummaryText({
    required String status,
    required String callType,
    required int durationSeconds,
  }) {
    final callLabel = callType == 'video' ? 'Cuộc gọi video' : 'Cuộc gọi thoại';

    switch (status) {
      case 'missed':
        return 'Cuộc gọi bị bỏ lỡ';
      case 'rejected':
        return 'Cuộc gọi bị từ chối';
      case 'busy':
        return 'Đối phương đang bận';
      case 'ended':
      default:
        if (durationSeconds > 0) {
          return '$callLabel • ${_formatDuration(durationSeconds)}';
        }
        return '$callLabel đã kết thúc';
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours giờ $minutes phút $seconds giây';
    }
    if (minutes > 0) {
      return '$minutes phút $seconds giây';
    }
    return '$seconds giây';
  }

  String? _asString(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  Timestamp? _asTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }
}
