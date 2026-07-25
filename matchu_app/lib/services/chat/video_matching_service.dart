import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';
import 'package:matchu_app/repositories/matching/video_matching_repository.dart';
import 'package:matchu_app/services/chat/call_signaling_service.dart';
import 'package:matchu_app/services/chat/rating_service.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';

class VideoMatchingService implements VideoMatchingRepository {
  VideoMatchingService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    CallSignalingService? signalingService,
    TempChatService? tempChatService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _signalingService = signalingService ?? CallSignalingService(),
       _tempChatService = tempChatService ?? TempChatService();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final CallSignalingService _signalingService;
  final TempChatService _tempChatService;

  static const String _queueCollection = 'tempChatMatchingQueue';

  @override
  Future<String?> startMatching({
    required String sessionId,
    required String targetGender,
    required String anonymousAvatar,
    required String faceProofId,
    required String deviceId,
  }) async {
    final result = await _functions
        .httpsCallable('startTempChatMatching')
        .call({
          'sessionId': sessionId,
          'targetGender': targetGender,
          'anonymousAvatar': anonymousAvatar,
          'matchingMode': 'video',
          'faceProofId': faceProofId,
          'deviceId': deviceId,
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['roomId']?.toString();
  }

  @override
  Future<void> cancelMatching({required String sessionId}) async {
    await _functions.httpsCallable('cancelTempChatMatching').call({
      'sessionId': sessionId,
    });
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenMatchingSession(
    String uid,
  ) {
    return _firestore.collection(_queueCollection).doc(uid).snapshots();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _firestore.collection('tempChats').doc(roomId).snapshots();
  }

  @override
  Future<ChatPeerSummary?> getPeerSummary(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    return data == null ? null : ChatPeerSummary.fromMap(data);
  }

  @override
  Future<void> setLike({required String roomId, required String uid}) {
    return _tempChatService.setLike(roomId: roomId, uid: uid, value: true);
  }

  @override
  Future<void> autoRateSuccessfulMatch({
    required String roomId,
    required String fromUid,
    required String toUid,
  }) {
    return RatingService.autoRate(
      roomId: roomId,
      fromUid: fromUid,
      toUid: toUid,
    );
  }

  @override
  Future<void> setCameraEnabled({
    required String roomId,
    required String uid,
    required bool enabled,
  }) async {
    final roomRef = _firestore.collection('tempChats').doc(roomId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data();
      if (data == null ||
          data['status'] != 'active' ||
          data['matchingMode'] != 'video') {
        throw StateError('Video room is no longer active.');
      }

      final participants = List<String>.from(
        data['participants'] ?? const <String>[],
      );
      if (!participants.contains(uid)) {
        throw StateError('Current user is not a room participant.');
      }

      final unlockAt = data['cameraUnlockAt'];
      if (unlockAt is! Timestamp ||
          DateTime.now().isBefore(unlockAt.toDate())) {
        throw StateError('Camera is still locked.');
      }

      transaction.update(roomRef, {'videoCameraStates.$uid': enabled});
    });
  }

  @override
  Future<void> setMuted({
    required String roomId,
    required String uid,
    required bool muted,
  }) async {
    final roomRef = _firestore.collection('tempChats').doc(roomId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data();
      if (data == null ||
          data['status'] != 'active' ||
          data['matchingMode'] != 'video') {
        throw StateError('Video room is no longer active.');
      }

      final participants = List<String>.from(
        data['participants'] ?? const <String>[],
      );
      if (!participants.contains(uid)) {
        throw StateError('Current user is not a room participant.');
      }

      final current = Map<String, dynamic>.from(
        data['videoMutedStates'] ?? const <String, dynamic>{},
      );
      final next = <String, bool>{
        for (final participant in participants)
          participant: current[participant] == true,
      };
      next[uid] = muted;
      transaction.update(roomRef, {'videoMutedStates': next});
    });
  }

  @override
  Future<void> endRoom({
    required String roomId,
    required String uid,
    required String reason,
  }) {
    return _tempChatService.endRoom(roomId: roomId, uid: uid, reason: reason);
  }

  @override
  Future<void> extendRoom(String roomId) {
    return _tempChatService.extendRoom(roomId);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenCallSession(
    String callId,
  ) {
    return _signalingService.listenCallDocument(callId);
  }

  @override
  Future<void> updateOffer({
    required String callId,
    required Map<String, dynamic> offer,
  }) {
    return _signalingService.updateOffer(callId: callId, offer: offer);
  }

  @override
  Future<void> updateAnswer({
    required String callId,
    required Map<String, dynamic> answer,
  }) {
    return _signalingService.updateAnswer(callId: callId, answer: answer);
  }

  @override
  Future<void> addIceCandidate({
    required String callId,
    required bool isCaller,
    required String senderId,
    required RTCIceCandidate candidate,
  }) {
    return _signalingService.addIceCandidate(
      callId: callId,
      isCaller: isCaller,
      senderId: senderId,
      candidate: candidate,
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> listenRemoteIceCandidates({
    required String callId,
    required bool isCaller,
  }) {
    return _signalingService.listenRemoteIceCandidates(
      callId: callId,
      isCaller: isCaller,
    );
  }

  @override
  Future<void> endCallSession(String callId) {
    return _signalingService.endCall(callId);
  }
}
