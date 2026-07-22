import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';

/// Data boundary for anonymous video matching and its WebRTC signaling.
abstract class VideoMatchingRepository {
  Future<String?> startMatching({
    required String sessionId,
    required String targetGender,
    required String anonymousAvatar,
  });

  Future<void> cancelMatching({required String sessionId});

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenMatchingSession(
    String uid,
  );

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId);

  Future<ChatPeerSummary?> getPeerSummary(String uid);

  Future<void> setLike({required String roomId, required String uid});

  Future<void> autoRateSuccessfulMatch({
    required String roomId,
    required String fromUid,
    required String toUid,
  });

  Future<void> setCameraEnabled({
    required String roomId,
    required String uid,
    required bool enabled,
  });

  Future<void> setMuted({
    required String roomId,
    required String uid,
    required bool muted,
  });

  Future<void> endRoom({
    required String roomId,
    required String uid,
    required String reason,
  });

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenCallSession(
    String callId,
  );

  Future<void> updateOffer({
    required String callId,
    required Map<String, dynamic> offer,
  });

  Future<void> updateAnswer({
    required String callId,
    required Map<String, dynamic> answer,
  });

  Future<void> addIceCandidate({
    required String callId,
    required bool isCaller,
    required String senderId,
    required RTCIceCandidate candidate,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> listenRemoteIceCandidates({
    required String callId,
    required bool isCaller,
  });

  Future<void> endCallSession(String callId);
}
