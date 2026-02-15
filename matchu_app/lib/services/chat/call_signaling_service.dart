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
}
