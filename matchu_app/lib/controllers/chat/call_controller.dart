import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/chat/call_signaling_service.dart';
import 'package:matchu_app/services/chat/ice_server_service.dart';
import 'package:matchu_app/services/chat/webrtc_service.dart';
import 'package:matchu_app/services/user/user_service.dart';

enum CallUiState { idle, creating, ringing, connecting, active, ended, error }

class CallController extends GetxController {
  final CallSignalingService _signalingService = CallSignalingService();
  final WebRTCService _webRTCService = WebRTCService();
  final IceServerService _iceServerService = IceServerService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxnString currentUserId = RxnString();
  final RxnString currentCallId = RxnString();
  final RxnString currentRoomChatId = RxnString();
  final RxnString peerUserId = RxnString();
  final RxString peerName = 'Unknown user'.obs;
  final RxString peerAvatarUrl = ''.obs;
  final RxString callType = 'audio'.obs; // "audio" or "video"
  final RxBool isCaller = false.obs;
  final RxBool isMuted = false.obs;
  final RxBool isCameraEnabled = true.obs;
  final Rx<CallUiState> callState = CallUiState.idle.obs;
  final RxnString errorMessage = RxnString();

  RTCVideoRenderer get localRenderer => _webRTCService.localRenderer;
  RTCVideoRenderer get remoteRenderer => _webRTCService.remoteRenderer;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingCallSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _remoteIceSub;

  final Set<String> _handledRemoteCandidateIds = <String>{};
  final List<RTCIceCandidate> _pendingLocalCandidates = <RTCIceCandidate>[];
  Timer? _ringingTimeout;
  bool _isSettingRemoteDescription = false;
  bool _isEndingCall = false;
  bool _hasAcceptedCall = false;
  bool _didIceRestartAttempt = false;
  String? _lastAppliedAnswerSdp;
  String? _lastAppliedOfferSdp;

  static const Duration _maxRingingDuration = Duration(seconds: 45);

  @override
  void onInit() {
    super.onInit();
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
    _onAuthChanged(_auth.currentUser);
    _warmUpRenderers();
  }

  String get callStatusText {
    switch (callState.value) {
      case CallUiState.creating:
        return 'Creating call...';
      case CallUiState.ringing:
        return isCaller.value ? 'Ringing...' : 'Incoming call';
      case CallUiState.connecting:
        return 'Connecting...';
      case CallUiState.active:
        return 'Connected';
      case CallUiState.ended:
        return 'Call ended';
      case CallUiState.error:
        return errorMessage.value ?? 'Call error';
      case CallUiState.idle:
        return '';
    }
  }

  bool get isVideoCall => callType.value == 'video';

  Future<void> startCall(
    String roomChatId,
    String receiverId,
    String type,
  ) async {
    final callerId = currentUserId.value;
    if (callerId == null || callerId.isEmpty) {
      _setError('You must login before placing a call.');
      return;
    }
    if (roomChatId.isEmpty || receiverId.isEmpty) {
      _setError('Invalid room or receiver.');
      return;
    }
    if (receiverId == callerId) {
      _setError('Cannot call your own account.');
      return;
    }
    if (callState.value != CallUiState.idle && currentCallId.value != null) {
      _setError('A call is already in progress.');
      return;
    }

    final normalizedType = _normalizeCallType(type);

    try {
      errorMessage.value = null;
      callState.value = CallUiState.creating;
      isCaller.value = true;
      isMuted.value = false;
      isCameraEnabled.value = normalizedType == 'video';
      _hasAcceptedCall = false;
      _didIceRestartAttempt = false;
      _isSettingRemoteDescription = false;
      _lastAppliedAnswerSdp = null;
      _lastAppliedOfferSdp = null;
      callType.value = normalizedType;
      currentRoomChatId.value = roomChatId;
      peerUserId.value = receiverId;
      _openCallView('pending');
      _loadPeerInfoInBackground(receiverId);

      await _webRTCService.initPeerConnection(
        withVideo: normalizedType == 'video',
        onIceCandidate: (candidate) => _addLocalCandidate(candidate),
        onConnectionStateChanged: _handleConnectionStateChanged,
        iceServers: await _iceServerService.getIceServers(),
      );

      final offer = await _webRTCService.createOffer();
      final callId = await _signalingService.createCallDocument(
        roomChatId: roomChatId,
        callerId: callerId,
        receiverId: receiverId,
        type: normalizedType,
        offer: _sessionDescriptionToMap(offer),
      );

      currentCallId.value = callId;
      await _flushPendingLocalCandidates();
      callState.value = CallUiState.ringing;
      _startRingingTimeout(callId);

      await _subscribeToCall(callId, callerSide: true);
      await _subscribeToRemoteIceCandidates(callId, callerSide: true);
    } catch (error) {
      debugPrint('startCall error: $error');
      _setError('Unable to start call.');
      await _clearLocalSession(popScreens: true);
    }
  }

  Future<void> acceptCall(String callId) async {
    final myUid = currentUserId.value;
    if (myUid == null || myUid.isEmpty) {
      _setError('You must login before accepting a call.');
      return;
    }
    if (callId.isEmpty) {
      _setError('Invalid call ID.');
      return;
    }

    try {
      final snapshot = await _signalingService.getCallDocument(callId);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        _setError('Call no longer exists.');
        return;
      }

      final receiverId = data['receiverId'] as String? ?? '';
      if (receiverId != myUid) {
        _setError('This call is not assigned to current user.');
        return;
      }

      final status = data['status'] as String? ?? '';
      if (status != 'ringing') {
        _setError('Call is no longer ringing.');
        return;
      }

      final remoteOffer = _parseMap(data['offer']);
      if (remoteOffer == null) {
        _setError('Missing offer from caller.');
        return;
      }

      final callerId = data['callerId'] as String? ?? '';
      final roomChatId = data['roomChatId'] as String? ?? '';
      final normalizedType = _normalizeCallType(data['type'] as String?);

      errorMessage.value = null;
      currentCallId.value = callId;
      currentRoomChatId.value = roomChatId;
      peerUserId.value = callerId;
      _loadPeerInfoInBackground(callerId);
      callType.value = normalizedType;
      callState.value = CallUiState.connecting;
      isCaller.value = false;
      isMuted.value = false;
      isCameraEnabled.value = normalizedType == 'video';
      _hasAcceptedCall = true;
      _didIceRestartAttempt = false;
      _isSettingRemoteDescription = false;
      _lastAppliedAnswerSdp = null;
      _openCallView(callId, replaceIncoming: true);

      await _webRTCService.initPeerConnection(
        withVideo: normalizedType == 'video',
        onIceCandidate: (candidate) => _addLocalCandidate(candidate),
        onConnectionStateChanged: _handleConnectionStateChanged,
        iceServers: await _iceServerService.getIceServers(),
      );

      _isSettingRemoteDescription = true;
      await _webRTCService.setRemoteDescription(remoteOffer);
      _lastAppliedOfferSdp = remoteOffer['sdp'] as String?;
      _cancelRingingTimeout();

      final answer = await _webRTCService.createAnswer();
      await _signalingService.updateAnswer(
        callId: callId,
        answer: _sessionDescriptionToMap(answer),
      );
      _isSettingRemoteDescription = false;

      await _subscribeToCall(callId, callerSide: false);
      await _subscribeToRemoteIceCandidates(callId, callerSide: false);
    } catch (error) {
      debugPrint('acceptCall error: $error');
      _setError('Unable to accept call.');
      await _clearLocalSession(popScreens: true);
    }
  }

  Future<void> rejectCall(String callId) async {
    if (callId.isEmpty) return;

    try {
      await _signalingService.rejectCall(callId);
    } catch (error) {
      debugPrint('rejectCall error: $error');
    } finally {
      if (currentCallId.value == callId) {
        await _clearLocalSession(popScreens: true);
      } else {
        _popIncomingViewIfVisible();
      }
    }
  }

  Future<void> endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    final callId = currentCallId.value;

    try {
      if (callId != null && callId.isNotEmpty) {
        await _signalingService.endCall(callId);
      }
    } catch (error) {
      debugPrint('endCall error: $error');
    } finally {
      await _clearLocalSession(popScreens: true);
      _isEndingCall = false;
    }
  }

  Future<void> toggleMute() async {
    final nextMuted = !isMuted.value;
    await _webRTCService.setMicrophoneEnabled(!nextMuted);
    isMuted.value = nextMuted;
  }

  Future<void> toggleCamera() async {
    if (!isVideoCall) return;
    final nextEnabled = !isCameraEnabled.value;
    await _webRTCService.setCameraEnabled(nextEnabled);
    isCameraEnabled.value = nextEnabled;
  }

  Future<void> switchCamera() {
    if (!isVideoCall) return Future.value();
    return _webRTCService.switchCamera();
  }

  void _onAuthChanged(User? user) {
    if (user == null) {
      currentUserId.value = null;
      _iceServerService.clearCache();
      _incomingCallSub?.cancel();
      _incomingCallSub = null;
      unawaited(_clearLocalSession(popScreens: true));
      return;
    }

    currentUserId.value = user.uid;
    _startIncomingCallListener(user.uid);
  }

  void _startIncomingCallListener(String uid) {
    _incomingCallSub?.cancel();
    _incomingCallSub = _signalingService
        .listenIncomingCall(uid)
        .listen(
          (snapshot) async {
            try {
              if (snapshot.docs.isEmpty) return;

              final incoming = snapshot.docs.first;
              final callId = incoming.id;
              final data = incoming.data();
              final callerId = data['callerId'] as String? ?? '';
              final roomChatId = data['roomChatId'] as String? ?? '';
              final type = _normalizeCallType(data['type'] as String?);

              if (callerId.isEmpty) return;

              // If user is busy on another call, reject new incoming call as busy.
              final activeCallId = currentCallId.value;
              if (activeCallId != null && activeCallId != callId) {
                await _signalingService.rejectCall(callId, reason: 'busy');
                return;
              }

              if (callState.value != CallUiState.idle &&
                  activeCallId != callId) {
                await _signalingService.rejectCall(callId, reason: 'busy');
                return;
              }

              currentCallId.value = callId;
              currentRoomChatId.value = roomChatId;
              peerUserId.value = callerId;
              callType.value = type;
              isCaller.value = false;
              callState.value = CallUiState.ringing;
              isMuted.value = false;
              isCameraEnabled.value = type == 'video';
              _openIncomingCallView(callId);
              _loadPeerInfoInBackground(callerId);
              await _subscribeToCall(callId, callerSide: false);
            } catch (error) {
              debugPrint('incoming call listener error: $error');
            }
          },
          onError: (error) {
            debugPrint('incoming call stream error: $error');
          },
        );
  }

  Future<void> _subscribeToCall(
    String callId, {
    required bool callerSide,
  }) async {
    await _callDocSub?.cancel();
    _callDocSub = _signalingService.listenCallDocument(callId).listen((
      snapshot,
    ) async {
      try {
        if (!snapshot.exists) {
          await _clearLocalSession(popScreens: true);
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final status = data['status'] as String? ?? '';

        if (callerSide) {
          final answer = _parseMap(data['answer']);
          final answerSdp = answer?['sdp'];
          final hasNewAnswer =
              answer != null &&
              answerSdp is String &&
              answerSdp.isNotEmpty &&
              answerSdp != _lastAppliedAnswerSdp;

          if (hasNewAnswer && !_isSettingRemoteDescription) {
            _isSettingRemoteDescription = true;
            try {
              _cancelRingingTimeout();
              await _webRTCService.setRemoteDescription(answer);
              _lastAppliedAnswerSdp = answerSdp;
              callState.value = CallUiState.connecting;
            } finally {
              _isSettingRemoteDescription = false;
            }
          }
        } else if (_hasAcceptedCall) {
          // Handle offer updates from caller (e.g. ICE restart renegotiation).
          final offer = _parseMap(data['offer']);
          final offerSdp = offer?['sdp'];
          final hasNewOffer =
              offer != null &&
              offerSdp is String &&
              offerSdp.isNotEmpty &&
              offerSdp != _lastAppliedOfferSdp;

          if (hasNewOffer && !_isSettingRemoteDescription) {
            _isSettingRemoteDescription = true;
            try {
              await _webRTCService.setRemoteDescription(offer);
              _lastAppliedOfferSdp = offerSdp;
              final answer = await _webRTCService.createAnswer();
              await _signalingService.updateAnswer(
                callId: callId,
                answer: _sessionDescriptionToMap(answer),
              );
              callState.value = CallUiState.connecting;
            } finally {
              _isSettingRemoteDescription = false;
            }
          }
        }

        if (status == 'active' && callState.value != CallUiState.active) {
          _cancelRingingTimeout();
          callState.value = CallUiState.connecting;
        }

        if (_isTerminalStatus(status)) {
          await _clearLocalSession(popScreens: true);
        }
      } catch (error) {
        debugPrint('call document listener error: $error');
      }
    });
  }

  Future<void> _subscribeToRemoteIceCandidates(
    String callId, {
    required bool callerSide,
  }) async {
    await _remoteIceSub?.cancel();
    _handledRemoteCandidateIds.clear();

    _remoteIceSub = _signalingService
        .listenRemoteIceCandidates(callId: callId, isCaller: callerSide)
        .listen((snapshot) async {
          for (final doc in snapshot.docs) {
            if (_handledRemoteCandidateIds.contains(doc.id)) continue;

            _handledRemoteCandidateIds.add(doc.id);

            try {
              await _webRTCService.addRemoteIceCandidate(doc.data());
            } catch (error) {
              debugPrint('remote ICE add error: $error');
            }
          }
        });
  }

  Future<void> _addLocalCandidate(RTCIceCandidate candidate) async {
    final callId = currentCallId.value;
    final userId = currentUserId.value;
    if (userId == null || userId.isEmpty) {
      return;
    }

    if (callId == null || callId.isEmpty) {
      _pendingLocalCandidates.add(candidate);
      return;
    }

    try {
      await _signalingService.addIceCandidate(
        callId: callId,
        isCaller: isCaller.value,
        senderId: userId,
        candidate: candidate,
      );
    } catch (error) {
      debugPrint('local ICE add error: $error');
    }
  }

  Future<void> _flushPendingLocalCandidates() async {
    final callId = currentCallId.value;
    final userId = currentUserId.value;

    if (callId == null || callId.isEmpty || userId == null || userId.isEmpty) {
      return;
    }
    if (_pendingLocalCandidates.isEmpty) return;

    final queued = List<RTCIceCandidate>.from(_pendingLocalCandidates);
    _pendingLocalCandidates.clear();

    for (final candidate in queued) {
      try {
        await _signalingService.addIceCandidate(
          callId: callId,
          isCaller: isCaller.value,
          senderId: userId,
          candidate: candidate,
        );
      } catch (error) {
        debugPrint('flush local ICE error: $error');
      }
    }
  }

  void _handleConnectionStateChanged(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _cancelRingingTimeout();
        _didIceRestartAttempt = false;
        callState.value = CallUiState.active;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        if (callState.value != CallUiState.ringing) {
          callState.value = CallUiState.connecting;
        }
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        // Keep call alive while caller is still waiting for answer.
        final waitingForAnswer =
            isCaller.value &&
            _lastAppliedAnswerSdp == null &&
            (callState.value == CallUiState.creating ||
                callState.value == CallUiState.ringing ||
                callState.value == CallUiState.connecting);

        if (waitingForAnswer) {
          debugPrint(
            'Ignore $state while waiting for remote answer to avoid ending too early.',
          );
          return;
        }

        if (!_didIceRestartAttempt) {
          _didIceRestartAttempt = true;
          unawaited(_attemptIceRestart());
          return;
        }
        unawaited(endCall());
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        break;
    }
  }

  void _startRingingTimeout(String callId) {
    _ringingTimeout?.cancel();
    _ringingTimeout = Timer(_maxRingingDuration, () async {
      if (currentCallId.value != callId) return;
      if (callState.value != CallUiState.ringing) return;

      try {
        await _signalingService.rejectCall(callId, reason: 'missed');
      } catch (error) {
        debugPrint('ringing timeout update error: $error');
      } finally {
        await _clearLocalSession(popScreens: true);
      }
    });
  }

  void _cancelRingingTimeout() {
    _ringingTimeout?.cancel();
    _ringingTimeout = null;
  }

  Future<void> _attemptIceRestart() async {
    final callId = currentCallId.value;
    if (callId == null || callId.isEmpty) {
      await endCall();
      return;
    }

    if (!isCaller.value) {
      // Only caller initiates restart offer in current signaling flow.
      await endCall();
      return;
    }

    try {
      callState.value = CallUiState.connecting;

      try {
        await _webRTCService.restartIce();
      } catch (_) {
        // Some platforms ignore restartIce; we still renegotiate with iceRestart offer.
      }

      final restartOffer = await _webRTCService.createOffer(iceRestart: true);
      await _signalingService.updateOffer(
        callId: callId,
        offer: _sessionDescriptionToMap(restartOffer),
      );
    } catch (error) {
      debugPrint('ICE restart failed: $error');
      await endCall();
    }
  }

  Future<void> _clearLocalSession({required bool popScreens}) async {
    _cancelRingingTimeout();
    await _callDocSub?.cancel();
    _callDocSub = null;
    await _remoteIceSub?.cancel();
    _remoteIceSub = null;

    _handledRemoteCandidateIds.clear();
    _pendingLocalCandidates.clear();
    _isSettingRemoteDescription = false;
    _hasAcceptedCall = false;
    _didIceRestartAttempt = false;
    _lastAppliedAnswerSdp = null;
    _lastAppliedOfferSdp = null;

    await _webRTCService.resetConnection();

    currentCallId.value = null;
    currentRoomChatId.value = null;
    peerUserId.value = null;
    peerName.value = 'Unknown user';
    peerAvatarUrl.value = '';
    callType.value = 'audio';
    isCaller.value = false;
    isMuted.value = false;
    isCameraEnabled.value = true;
    callState.value = CallUiState.idle;

    if (popScreens) {
      _closeCallScreens();
    }
  }

  Future<void> _loadPeerInfo(String uid) async {
    if (uid.isEmpty) {
      peerName.value = 'Unknown user';
      peerAvatarUrl.value = '';
      return;
    }

    if (Get.isRegistered<ChatUserCacheController>()) {
      final cache = Get.find<ChatUserCacheController>();
      final cached = cache.getUser(uid);
      if (cached != null) {
        final name = cached.fullname.trim();
        peerName.value = name.isNotEmpty ? name : cached.nickname;
        peerAvatarUrl.value = cached.avatarUrl;
        return;
      }
      cache.loadIfNeeded(uid);
    }

    final user = await _userService.getUser(uid);
    if (user == null) return;

    final name = user.fullname.trim();
    peerName.value = name.isNotEmpty ? name : user.nickname;
    peerAvatarUrl.value = user.avatarUrl;
  }

  void _loadPeerInfoInBackground(String uid) {
    unawaited(
      _loadPeerInfo(uid).catchError((error) {
        debugPrint('load peer info background error: $error');
      }),
    );
  }

  void _warmUpRenderers() {
    unawaited(
      _webRTCService.initRenderers().catchError((error) {
        debugPrint('renderer warmup error: $error');
      }),
    );
  }

  String _normalizeCallType(String? type) {
    return type == 'video' ? 'video' : 'audio';
  }

  Map<String, dynamic> _sessionDescriptionToMap(RTCSessionDescription sdp) {
    return {'sdp': sdp.sdp, 'type': sdp.type};
  }

  Map<String, dynamic>? _parseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  bool _isTerminalStatus(String status) {
    return status == 'ended' ||
        status == 'rejected' ||
        status == 'busy' ||
        status == 'missed';
  }

  void _setError(String message) {
    errorMessage.value = message;
    callState.value = CallUiState.error;
    Get.snackbar('Call', message);
  }

  void _openIncomingCallView(String callId) {
    if (Get.currentRoute == AppRouter.call) return;
    if (Get.currentRoute == AppRouter.incomingCall) return;

    Get.toNamed(
      AppRouter.incomingCall,
      arguments: {'callId': callId},
      preventDuplicates: false,
    );
  }

  void _openCallView(String callId, {bool replaceIncoming = false}) {
    if (replaceIncoming || Get.currentRoute == AppRouter.incomingCall) {
      Get.offNamed(AppRouter.call, arguments: {'callId': callId});
      return;
    }

    if (Get.currentRoute == AppRouter.call) return;

    Get.toNamed(
      AppRouter.call,
      arguments: {'callId': callId},
      preventDuplicates: false,
    );
  }

  void _popIncomingViewIfVisible() {
    if (Get.currentRoute == AppRouter.incomingCall) {
      Get.back();
    }
  }

  void _closeCallScreens() {
    if (Get.currentRoute == AppRouter.call ||
        Get.currentRoute == AppRouter.incomingCall) {
      Get.back();
    }
  }

  @override
  void onClose() {
    _cancelRingingTimeout();
    _authSub?.cancel();
    _incomingCallSub?.cancel();
    _callDocSub?.cancel();
    _remoteIceSub?.cancel();
    unawaited(_webRTCService.disposeAll());
    super.onClose();
  }
}
