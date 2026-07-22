import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/repositories/matching/video_matching_repository.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/chat/ice_server_service.dart';
import 'package:matchu_app/services/chat/webrtc_service.dart';
import 'package:matchu_app/translations/video_matching_translations.dart';
import 'package:matchu_app/views/matching/match_transition_view.dart';

enum VideoMatchingPhase {
  preparing,
  searching,
  connecting,
  active,
  ending,
  ended,
  converting,
  error,
}

class VideoMatchingController extends GetxController {
  VideoMatchingController({
    required this.targetGender,
    required this.anonymousAvatar,
    required VideoMatchingRepository repository,
    WebRTCService? webRTCService,
    IceServerService? iceServerService,
  }) : _repository = repository,
       _webRTC = webRTCService ?? WebRTCService(),
       _iceServerService = iceServerService ?? IceServerService();

  final String targetGender;
  final String anonymousAvatar;
  final VideoMatchingRepository _repository;
  final WebRTCService _webRTC;
  final IceServerService _iceServerService;

  final phase = VideoMatchingPhase.preparing.obs;
  final previewReady = false.obs;
  final canCancel = false.obs;
  final searchElapsedSeconds = 0.obs;
  final roomRemainingSeconds = (8 * 60).obs;
  final cameraUnlockRemainingSeconds = 90.obs;
  final cameraUnlocked = false.obs;
  final isMuted = false.obs;
  final localCameraEnabled = false.obs;
  final remoteCameraEnabled = false.obs;
  final hasLiked = false.obs;
  final otherLiked = false.obs;
  final otherAnonymousAvatar = 'avt_01'.obs;
  final errorMessage = RxnString();

  RTCVideoRenderer get localRenderer => _webRTC.localRenderer;
  RTCVideoRenderer get remoteRenderer => _webRTC.remoteRenderer;

  String get uid => Get.find<AuthController>().user!.uid;

  String get formattedSearchTime => _formatDuration(searchElapsedSeconds.value);
  String get formattedRoomTime => _formatDuration(roomRemainingSeconds.value);

  String? _sessionId;
  String? _roomId;
  String? _otherUid;
  String? _callId;
  DateTime? _expiresAt;
  DateTime? _cameraUnlockAt;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _queueSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _remoteIceSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _clock;
  Timer? _disconnectTimer;

  final Set<String> _handledRemoteCandidateIds = <String>{};
  final Set<String> _videoParticipantsSeenEnabled = <String>{};
  final List<Map<String, dynamic>> _pendingRemoteCandidates = [];
  Map<String, dynamic>? _pendingCallSessionData;
  bool _isCaller = false;
  bool _remoteDescriptionSet = false;
  bool _processingDescription = false;
  bool _connectionStarted = false;
  bool _initialNegotiationComplete = false;
  bool _videoNegotiationInFlight = false;
  bool _handlingRoom = false;
  bool _exitInProgress = false;
  bool _navigatingToChat = false;
  bool _navigatingToRating = false;
  bool _disposed = false;
  String? _lastOfferSdp;
  String? _lastAnswerSdp;
  String? _videoOfferSignature;
  String _negotiatedVideoSignature = '';

  @override
  void onInit() {
    super.onInit();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) return;
      if (phase.value == VideoMatchingPhase.ended ||
          phase.value == VideoMatchingPhase.error) {
        return;
      }
      unawaited(_showConnectionError());
    });
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(startSearch());
  }

  Future<void> startSearch() async {
    if (_disposed || _handlingRoom || _exitInProgress) return;

    await _cancelRoomSubscriptions();
    await _webRTC.resetConnection();
    _resetForSearch();

    try {
      phase.value = VideoMatchingPhase.preparing;
      await _webRTC.initPeerConnection(
        withVideo: true,
        onIceCandidate: (_) async {},
        onConnectionStateChanged: (_) {},
        iceServers: await _iceServerService.getIceServers(),
      );
      await _webRTC.setMicrophoneEnabled(false);
      await _webRTC.setCameraEnabled(true);
      if (_disposed) return;

      previewReady.value = true;
      phase.value = VideoMatchingPhase.searching;
      _startClock();
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (!_disposed && phase.value == VideoMatchingPhase.searching) {
          canCancel.value = true;
        }
      });

      final sessionId = '${uid}_${DateTime.now().microsecondsSinceEpoch}';
      _sessionId = sessionId;
      final roomId = await _repository.startMatching(
        sessionId: sessionId,
        targetGender: targetGender,
        anonymousAvatar: anonymousAvatar,
      );
      if (_disposed || _sessionId != sessionId) {
        // Cancellation may race the callable before it writes the queue. A
        // second cancellation after the callable returns closes that window.
        try {
          await _repository.cancelMatching(sessionId: sessionId);
          if (roomId != null && roomId.isNotEmpty) {
            await _repository.endRoom(roomId: roomId, uid: uid, reason: 'left');
          }
        } catch (error) {
          debugPrint('Late video matching cancellation failed: $error');
        }
        return;
      }

      if (roomId != null && roomId.isNotEmpty) {
        await _openRoom(roomId);
        return;
      }

      _queueSub = _repository.listenMatchingSession(uid).listen((snapshot) {
        final data = snapshot.data();
        if (data == null || data['sessionId'] != sessionId) return;
        if (data['status'] == 'matched' && data['roomId'] is String) {
          unawaited(_openRoom(data['roomId'] as String));
        }
      }, onError: (Object error) => unawaited(_fail(error)));
    } catch (error, stackTrace) {
      debugPrint('Video matching start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _fail(error);
    }
  }

  Future<void> cancelSearch({bool closeRoute = true}) async {
    if (_exitInProgress) return;
    _exitInProgress = true;
    final sessionId = _sessionId;
    _sessionId = null;
    _stopClock();
    await _queueSub?.cancel();
    _queueSub = null;

    if (sessionId != null) {
      unawaited(_cancelSearchOnServer(sessionId));
    }

    _exitInProgress = false;
    if (closeRoute && !_disposed) {
      _closeMatchingRoute();
      return;
    }
    await _webRTC.resetConnection();
  }

  Future<void> _cancelSearchOnServer(String sessionId) async {
    try {
      await _repository
          .cancelMatching(sessionId: sessionId)
          .timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('Video matching cancellation sync failed: $error');
    }
  }

  void _closeMatchingRoute() {
    if (Get.currentRoute != AppRouter.videoMatching) return;

    // A matching route opened after Rating is the root route because Rating
    // uses offAllNamed. In that case Get.back() cannot pop anything and leaves
    // a stopped matching screen visible, which looks like the app is frozen.
    final canPop = Get.key.currentState?.canPop() ?? false;
    if (canPop) {
      Get.back();
    } else {
      Get.offAllNamed(AppRouter.main);
    }
  }

  Future<void> _openRoom(String roomId) async {
    if (_handlingRoom || _disposed) return;
    _handlingRoom = true;
    _roomId = roomId;
    _sessionId = null;
    canCancel.value = false;
    _stopClock();
    await _queueSub?.cancel();
    _queueSub = null;
    phase.value = VideoMatchingPhase.connecting;

    _roomSub = _repository.listenRoom(roomId).listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      unawaited(_handleRoomSnapshot(data));
    }, onError: (Object error) => unawaited(_fail(error)));
  }

  Future<void> _handleRoomSnapshot(Map<String, dynamic> data) async {
    if (_disposed || _navigatingToChat || _navigatingToRating) return;
    if (data['matchingMode'] != 'video') {
      await _fail(StateError('Matched room is not a video room.'));
      return;
    }

    final participants = List<String>.from(
      data['participants'] ?? const <String>[],
    );
    if (!participants.contains(uid)) {
      await _fail(StateError('Current user is not a room participant.'));
      return;
    }

    final isUserA = data['userA'] == uid;
    final otherUid = isUserA ? data['userB'] : data['userA'];
    _isCaller = isUserA;
    _otherUid = otherUid?.toString();

    final avatars = Map<String, dynamic>.from(
      data['anonymousAvatars'] ?? const <String, dynamic>{},
    );
    otherAnonymousAvatar.value = avatars[otherUid]?.toString() ?? 'avt_01';

    final cameraStates = Map<String, dynamic>.from(
      data['videoCameraStates'] ?? const <String, dynamic>{},
    );
    if (cameraStates[uid] == true) {
      _videoParticipantsSeenEnabled.add(uid);
    }
    if (cameraStates[otherUid] == true && otherUid is String) {
      _videoParticipantsSeenEnabled.add(otherUid);
    }
    remoteCameraEnabled.value = cameraStates[otherUid] == true;
    localCameraEnabled.value = cameraStates[uid] == true;

    hasLiked.value =
        (isUserA ? data['userALiked'] : data['userBLiked']) == true;
    final peerLiked =
        (isUserA ? data['userBLiked'] : data['userALiked']) == true;
    if (peerLiked && !otherLiked.value) {
      Get.snackbar(
        videoMatchingTr('Có người vừa thả tim bạn'),
        videoMatchingTr('Hãy thả tim nếu bạn cũng muốn tiếp tục làm quen.'),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        maxWidth: 420,
        duration: const Duration(seconds: 3),
      );
    }
    otherLiked.value = peerLiked;

    _expiresAt = _timestampDate(data['expiresAt']);
    _cameraUnlockAt = _timestampDate(data['cameraUnlockAt']);
    _syncRoomClock();
    _startClock();

    final status = data['status']?.toString();
    if (status == 'converted' && data['permanentRoomId'] is String) {
      await _goToPermanentRoom(data['permanentRoomId'] as String);
      return;
    }
    if (status == 'ended') {
      await _showEnded();
      return;
    }
    if (status != 'active') return;

    if (data['userALiked'] == true && data['userBLiked'] == true) {
      await _showMutualMatch();
      return;
    }

    final callId = data['callSessionId']?.toString();
    if (!_connectionStarted && callId != null && callId.isNotEmpty) {
      _connectionStarted = true;
      _callId = callId;
      await _startPeerConnection(callId);
    }

    _scheduleVideoRenegotiation();
  }

  Future<void> _startPeerConnection(String callId) async {
    try {
      await _webRTC.initPeerConnection(
        // The first 90 seconds are a real audio-only WebRTC session. A video
        // sender is added only after the server-provided unlock time.
        withVideo: false,
        onIceCandidate: (candidate) {
          return _repository.addIceCandidate(
            callId: callId,
            isCaller: _isCaller,
            senderId: uid,
            candidate: candidate,
          );
        },
        onConnectionStateChanged: _handleConnectionState,
        iceServers: await _iceServerService.getIceServers(),
      );
      await _webRTC.setMicrophoneEnabled(true);
      localCameraEnabled.value = false;

      _subscribeToCallSession(callId);
      _subscribeToRemoteCandidates(callId);

      if (_isCaller) {
        final offer = await _webRTC.createOffer();
        await _repository.updateOffer(
          callId: callId,
          offer: _descriptionMap(offer),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Anonymous video connection failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _fail(error);
    }
  }

  void _subscribeToCallSession(String callId) {
    _callSub = _repository.listenCallSession(callId).listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      _pendingCallSessionData = Map<String, dynamic>.from(data);
      unawaited(_drainCallSessionUpdates());
    }, onError: (Object error) => unawaited(_fail(error)));
  }

  Future<void> _drainCallSessionUpdates() async {
    if (_processingDescription ||
        _disposed ||
        _navigatingToChat ||
        _navigatingToRating) {
      return;
    }

    _processingDescription = true;
    try {
      while (_pendingCallSessionData != null &&
          !_disposed &&
          !_navigatingToChat &&
          !_navigatingToRating) {
        final data = _pendingCallSessionData!;
        _pendingCallSessionData = null;
        await _applyCallSessionUpdate(data);
      }
    } catch (error, stackTrace) {
      debugPrint('Anonymous video SDP processing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!_disposed && !_navigatingToChat && !_navigatingToRating) {
        await _fail(error);
      }
    } finally {
      _processingDescription = false;
      if (_pendingCallSessionData != null &&
          !_disposed &&
          !_navigatingToChat &&
          !_navigatingToRating) {
        unawaited(_drainCallSessionUpdates());
      }
    }
  }

  Future<void> _applyCallSessionUpdate(Map<String, dynamic> data) async {
    final status = data['status']?.toString();
    if (status == 'ended' || status == 'rejected' || status == 'missed') {
      await _showEnded();
      return;
    }

    if (_isCaller) {
      final answer = _mapValue(data['answer']);
      final answerSdp = answer?['sdp'];
      if (answer == null ||
          answerSdp is! String ||
          answerSdp.isEmpty ||
          answerSdp == _lastAnswerSdp) {
        return;
      }
      await _webRTC.setRemoteDescription(answer);
      _lastAnswerSdp = answerSdp;
      _remoteDescriptionSet = true;
      await _flushRemoteCandidates();

      if (_videoNegotiationInFlight) {
        _negotiatedVideoSignature =
            _videoOfferSignature ?? _currentVideoSignature;
        _videoOfferSignature = null;
        _videoNegotiationInFlight = false;
      } else {
        _initialNegotiationComplete = true;
      }
      _scheduleVideoRenegotiation();
      return;
    }

    final offer = _mapValue(data['offer']);
    final offerSdp = offer?['sdp'];
    if (offer == null ||
        offerSdp is! String ||
        offerSdp.isEmpty ||
        offerSdp == _lastOfferSdp) {
      return;
    }

    await _webRTC.setRemoteDescription(offer);
    _lastOfferSdp = offerSdp;
    _remoteDescriptionSet = true;
    await _flushRemoteCandidates();
    final answer = await _webRTC.createAnswer(
      receiveVideo: offerSdp.contains('m=video'),
    );
    await _repository.updateAnswer(
      callId: _callId!,
      answer: _descriptionMap(answer),
    );
  }

  void _subscribeToRemoteCandidates(String callId) {
    _handledRemoteCandidateIds.clear();
    _remoteIceSub = _repository
        .listenRemoteIceCandidates(callId: callId, isCaller: _isCaller)
        .listen((snapshot) {
          for (final document in snapshot.docs) {
            if (!_handledRemoteCandidateIds.add(document.id)) continue;
            final candidate = document.data();
            if (!_remoteDescriptionSet) {
              _pendingRemoteCandidates.add(candidate);
            } else {
              unawaited(_addRemoteCandidate(candidate));
            }
          }
        }, onError: (Object error) => debugPrint('Remote ICE error: $error'));
  }

  Future<void> _addRemoteCandidate(Map<String, dynamic> candidate) async {
    try {
      await _webRTC.addRemoteIceCandidate(candidate);
    } catch (error) {
      debugPrint('Unable to add anonymous video ICE candidate: $error');
    }
  }

  Future<void> _flushRemoteCandidates() async {
    final candidates = List<Map<String, dynamic>>.from(
      _pendingRemoteCandidates,
    );
    _pendingRemoteCandidates.clear();
    for (final candidate in candidates) {
      await _addRemoteCandidate(candidate);
    }
  }

  void _handleConnectionState(RTCPeerConnectionState state) {
    if (_disposed) return;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _disconnectTimer?.cancel();
        if (phase.value == VideoMatchingPhase.connecting) {
          phase.value = VideoMatchingPhase.active;
        }
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 10), () {
          if (!_disposed && phase.value == VideoMatchingPhase.active) {
            unawaited(_fail(StateError('Peer connection was lost.')));
          }
        });
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        break;
    }
  }

  Future<void> toggleMute() async {
    final next = !isMuted.value;
    await _webRTC.setMicrophoneEnabled(!next);
    isMuted.value = next;
  }

  Future<void> toggleCamera() async {
    final roomId = _roomId;
    if (!cameraUnlocked.value || roomId == null || _exitInProgress) return;

    final previous = localCameraEnabled.value;
    final next = !previous;
    try {
      if (next) await _webRTC.ensureLocalVideoTrack();
      await _webRTC.setCameraEnabled(next);
      localCameraEnabled.value = next;
      await _repository.setCameraEnabled(
        roomId: roomId,
        uid: uid,
        enabled: next,
      );
    } catch (error) {
      localCameraEnabled.value = previous;
      await _webRTC.setCameraEnabled(previous);
      Get.snackbar(
        videoMatchingTr('Không thể đổi trạng thái camera'),
        videoMatchingTr('Vui lòng thử lại sau một chút.'),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> switchCamera() async {
    if (!cameraUnlocked.value || !localCameraEnabled.value) return;
    await _webRTC.switchCamera();
  }

  String get _currentVideoSignature {
    final participants = _videoParticipantsSeenEnabled.toList()..sort();
    return participants.join('|');
  }

  void _scheduleVideoRenegotiation() {
    if (!_isCaller ||
        !_connectionStarted ||
        !_initialNegotiationComplete ||
        _videoNegotiationInFlight ||
        _disposed ||
        _navigatingToChat ||
        _navigatingToRating) {
      return;
    }
    final desiredSignature = _currentVideoSignature;
    if (desiredSignature.isEmpty ||
        desiredSignature == _negotiatedVideoSignature) {
      return;
    }
    unawaited(_renegotiateForVideo(desiredSignature));
  }

  Future<void> _renegotiateForVideo(String desiredSignature) async {
    final callId = _callId;
    if (callId == null || _videoNegotiationInFlight || !_isCaller) return;
    _videoNegotiationInFlight = true;
    _videoOfferSignature = desiredSignature;
    try {
      final offer = await _webRTC.createOffer(receiveVideo: true);
      await _repository.updateOffer(
        callId: callId,
        offer: _descriptionMap(offer),
      );
    } catch (error) {
      _videoNegotiationInFlight = false;
      _videoOfferSignature = null;
      debugPrint('Video renegotiation failed: $error');
      await _fail(error);
    }
  }

  Future<void> like() async {
    final roomId = _roomId;
    if (roomId == null || hasLiked.value || _exitInProgress) return;
    hasLiked.value = true;
    try {
      await _repository.setLike(roomId: roomId, uid: uid);
    } catch (error) {
      hasLiked.value = false;
      Get.snackbar(
        videoMatchingTr('Chưa thể thả tim'),
        videoMatchingTr('Vui lòng thử lại sau một chút.'),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> leaveRoom({required bool findNext}) async {
    await _finishWithoutMatch(reason: 'left', findNext: findNext);
  }

  Future<void> _finishWithoutMatch({
    required String reason,
    required bool findNext,
  }) async {
    if (_exitInProgress ||
        _navigatingToChat ||
        _navigatingToRating ||
        _disposed) {
      return;
    }
    _exitInProgress = true;
    _navigatingToRating = true;
    phase.value = VideoMatchingPhase.ending;
    final roomId = _roomId;
    final otherUid = _otherUid;
    final peerAvatar = otherAnonymousAvatar.value;
    final callId = _callId;

    // Stop room snapshots before writing the terminal state so both the local
    // exit and the remote listener cannot start rating navigation together.
    await _roomSub?.cancel();
    _roomSub = null;

    try {
      if (roomId != null) {
        await _repository
            .endRoom(roomId: roomId, uid: uid, reason: reason)
            .timeout(const Duration(seconds: 3));
      }
    } catch (error) {
      debugPrint('Video room exit sync failed: $error');
    }
    if (callId != null) {
      try {
        await _repository
            .endCallSession(callId)
            .timeout(const Duration(seconds: 2));
      } catch (error) {
        debugPrint('Video call exit sync failed: $error');
      }
    }

    await _cancelRoomSubscriptions();
    await _webRTC.resetConnection();
    _clearRoomIdentity();
    _handlingRoom = false;
    _exitInProgress = false;

    if (_disposed) return;
    await _openRating(
      roomId: roomId,
      otherUid: otherUid,
      peerAvatar: peerAvatar,
      findNext: findNext,
    );
  }

  Future<void> _expireRoom() async {
    if (_roomId == null) return;
    await _finishWithoutMatch(reason: 'timeout', findNext: false);
  }

  Future<void> _showEnded() async {
    if (_disposed || _navigatingToChat || _navigatingToRating) return;
    _navigatingToRating = true;
    final roomId = _roomId;
    final otherUid = _otherUid;
    final peerAvatar = otherAnonymousAvatar.value;
    phase.value = VideoMatchingPhase.ended;
    _stopClock();
    _disconnectTimer?.cancel();
    await _roomSub?.cancel();
    await _callSub?.cancel();
    await _remoteIceSub?.cancel();
    _roomSub = null;
    _callSub = null;
    _remoteIceSub = null;
    await _webRTC.resetConnection();
    _clearRoomIdentity();
    _handlingRoom = false;
    if (_disposed) return;
    await _openRating(
      roomId: roomId,
      otherUid: otherUid,
      peerAvatar: peerAvatar,
      findNext: false,
    );
  }

  Future<void> _showMutualMatch() async {
    if (_navigatingToChat || _disposed || _roomId == null) return;
    _navigatingToChat = true;
    phase.value = VideoMatchingPhase.converting;
    final roomId = _roomId!;
    final otherUid = _otherUid;
    final peerAvatar = otherAnonymousAvatar.value;
    await _autoRateSuccessfulMatch(roomId: roomId, otherUid: otherUid);
    await _cancelAllSubscriptions();
    await _webRTC.resetConnection();
    if (_disposed) return;

    Get.off(
      () => MatchTransitionView(
        tempRoomId: roomId,
        myAvatar: anonymousAvatar,
        otherAvatar: peerAvatar,
      ),
    );
  }

  Future<void> _goToPermanentRoom(String permanentRoomId) async {
    if (_navigatingToChat || _disposed) return;
    _navigatingToChat = true;
    phase.value = VideoMatchingPhase.converting;
    await _autoRateSuccessfulMatch(roomId: _roomId, otherUid: _otherUid);
    await _cancelAllSubscriptions();
    await _webRTC.resetConnection();
    if (!_disposed) {
      Get.offNamed('/chat', arguments: {'roomId': permanentRoomId});
    }
  }

  Future<void> _autoRateSuccessfulMatch({
    required String? roomId,
    required String? otherUid,
  }) async {
    if (roomId == null || otherUid == null || otherUid.isEmpty) return;
    try {
      await _repository.autoRateSuccessfulMatch(
        roomId: roomId,
        fromUid: uid,
        toUid: otherUid,
      );
    } catch (error) {
      // Rating must never block a successful mutual-match transition.
      debugPrint('Video mutual-match auto rating failed: $error');
    }
  }

  Future<void> _openRating({
    required String? roomId,
    required String? otherUid,
    required String peerAvatar,
    required bool findNext,
  }) async {
    if (_disposed) return;
    if (roomId == null || otherUid == null || otherUid.isEmpty) {
      _navigatingToRating = false;
      if (findNext) {
        await startSearch();
      } else {
        Get.offAllNamed(AppRouter.main);
      }
      return;
    }

    Get.offAllNamed(
      AppRouter.rating,
      arguments: {
        'roomId': roomId,
        'toUid': otherUid,
        'anonymousAvatar': peerAvatar,
        'experience': 'video',
        if (findNext) 'nextRoute': AppRouter.videoMatching,
        if (findNext)
          'nextRouteArguments': {
            'targetGender': targetGender,
            'anonymousAvatar': anonymousAvatar,
          },
      },
    );
  }

  Future<void> retry() async {
    errorMessage.value = null;
    _exitInProgress = false;
    _handlingRoom = false;
    await startSearch();
  }

  Future<void> closeError() async {
    await _cancelAllSubscriptions();
    await _webRTC.resetConnection();
    if (!_disposed) _closeMatchingRoute();
  }

  Future<void> _showConnectionError() async {
    await _fail(StateError('No network connection.'));
  }

  Future<void> _fail(Object error) async {
    if (_disposed || _navigatingToChat || _navigatingToRating) return;
    debugPrint('Anonymous video matching error: $error');
    errorMessage.value = videoMatchingTr(
      'Không thể duy trì kết nối. Hãy kiểm tra camera, micro và đường truyền rồi thử lại.',
    );
    phase.value = VideoMatchingPhase.error;
    final sessionId = _sessionId;
    final roomId = _roomId;
    final callId = _callId;
    _sessionId = null;
    if (sessionId != null) {
      unawaited(_repository.cancelMatching(sessionId: sessionId));
    }
    if (roomId != null) {
      try {
        await _repository
            .endRoom(roomId: roomId, uid: uid, reason: 'left')
            .timeout(const Duration(seconds: 2));
      } catch (syncError) {
        debugPrint('Unable to close failed video room: $syncError');
      }
    }
    if (callId != null) {
      try {
        await _repository
            .endCallSession(callId)
            .timeout(const Duration(seconds: 2));
      } catch (syncError) {
        debugPrint('Unable to close failed video signaling: $syncError');
      }
    }
    await _cancelAllSubscriptions();
    await _webRTC.resetConnection();
  }

  void _resetForSearch() {
    _clearRoomIdentity();
    previewReady.value = false;
    canCancel.value = false;
    searchElapsedSeconds.value = 0;
    roomRemainingSeconds.value = 8 * 60;
    cameraUnlockRemainingSeconds.value = 90;
    cameraUnlocked.value = false;
    isMuted.value = false;
    localCameraEnabled.value = false;
    remoteCameraEnabled.value = false;
    hasLiked.value = false;
    otherLiked.value = false;
    otherAnonymousAvatar.value = 'avt_01';
    errorMessage.value = null;
    _handlingRoom = false;
  }

  void _clearRoomIdentity() {
    _roomId = null;
    _otherUid = null;
    _callId = null;
    _expiresAt = null;
    _cameraUnlockAt = null;
    _connectionStarted = false;
    _initialNegotiationComplete = false;
    _videoNegotiationInFlight = false;
    _remoteDescriptionSet = false;
    _processingDescription = false;
    _pendingCallSessionData = null;
    _pendingRemoteCandidates.clear();
    _handledRemoteCandidateIds.clear();
    _videoParticipantsSeenEnabled.clear();
    _lastOfferSdp = null;
    _lastAnswerSdp = null;
    _videoOfferSignature = null;
    _negotiatedVideoSignature = '';
  }

  void _startClock() {
    if (_clock?.isActive == true) return;
    _stopClock();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (phase.value == VideoMatchingPhase.searching) {
        searchElapsedSeconds.value++;
      } else if (_roomId != null) {
        _syncRoomClock();
      }
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  void _syncRoomClock() {
    final now = DateTime.now();
    final expiresAt = _expiresAt;
    if (expiresAt != null) {
      final milliseconds = expiresAt.difference(now).inMilliseconds;
      roomRemainingSeconds.value =
          milliseconds <= 0 ? 0 : ((milliseconds + 999) ~/ 1000);
      if (milliseconds <= 0) unawaited(_expireRoom());
    }

    final unlockAt = _cameraUnlockAt;
    if (unlockAt != null) {
      final milliseconds = unlockAt.difference(now).inMilliseconds;
      cameraUnlockRemainingSeconds.value =
          milliseconds <= 0 ? 0 : ((milliseconds + 999) ~/ 1000);
      cameraUnlocked.value = milliseconds <= 0;
    }
  }

  Future<void> _cancelRoomSubscriptions() async {
    _stopClock();
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    await _roomSub?.cancel();
    await _callSub?.cancel();
    await _remoteIceSub?.cancel();
    _roomSub = null;
    _callSub = null;
    _remoteIceSub = null;
  }

  Future<void> _cancelAllSubscriptions() async {
    await _queueSub?.cancel();
    _queueSub = null;
    await _cancelRoomSubscriptions();
  }

  DateTime? _timestampDate(Object? value) {
    return value is Timestamp ? value.toDate() : null;
  }

  Map<String, dynamic>? _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic> _descriptionMap(RTCSessionDescription description) {
    return {'sdp': description.sdp, 'type': description.type};
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    _disposed = true;
    _stopClock();
    _disconnectTimer?.cancel();
    _connectivitySub?.cancel();
    unawaited(_cancelAllSubscriptions());
    unawaited(_webRTC.disposeAll());
    final sessionId = _sessionId;
    final roomId = _roomId;
    final callId = _callId;
    if (sessionId != null) {
      unawaited(_repository.cancelMatching(sessionId: sessionId));
    }
    if (!_navigatingToChat && roomId != null) {
      unawaited(_repository.endRoom(roomId: roomId, uid: uid, reason: 'left'));
      if (callId != null) unawaited(_repository.endCallSession(callId));
    }
    super.onClose();
  }
}
