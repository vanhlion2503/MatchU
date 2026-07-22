import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/matching/video_matching_session_coordinator.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';
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
  final allowRoutePop = false.obs;
  final previewReady = false.obs;
  final canCancel = false.obs;
  final searchElapsedSeconds = 0.obs;
  final roomRemainingSeconds = (8 * 60).obs;
  final cameraUnlockRemainingSeconds = 90.obs;
  final cameraUnlocked = false.obs;
  final isMuted = false.obs;
  final remoteMuted = false.obs;
  final localVoiceLevel = 0.0.obs;
  final remoteVoiceLevel = 0.0.obs;
  final localCameraEnabled = false.obs;
  final cameraToggleInProgress = false.obs;
  final remoteCameraEnabled = false.obs;
  final hasLiked = false.obs;
  final otherLiked = false.obs;
  final otherAnonymousAvatar = 'avt_01'.obs;
  final otherAvgRating = RxnDouble();
  final otherPeerSummary = Rxn<ChatPeerSummary>();
  final errorMessage = RxnString();

  RTCVideoRenderer get localRenderer => _webRTC.localRenderer;
  RTCVideoRenderer get remoteRenderer => _webRTC.remoteRenderer;

  String get uid => Get.find<AuthController>().user!.uid;

  String get formattedSearchTime => _formatDuration(searchElapsedSeconds.value);
  String get formattedRoomTime => _formatDuration(roomRemainingSeconds.value);

  VideoMatchingSessionCoordinator? get _sessionCoordinator {
    if (!Get.isRegistered<VideoMatchingSessionCoordinator>()) return null;
    return Get.find<VideoMatchingSessionCoordinator>();
  }

  String? _sessionId;
  String? _roomId;
  String? _otherUid;
  String? _ratingLoadedForUid;
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
  Timer? _audioLevelTimer;

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
  bool _pollingAudioLevels = false;
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
    _sessionCoordinator?.begin(onRestore: restoreMinimizedSearch);

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
      _sessionCoordinator?.finish();
      await _closeMatchingRoute();
      _scheduleControllerRelease();
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

  Future<void> _closeMatchingRoute() async {
    if (Get.currentRoute != AppRouter.videoMatching) return;

    allowRoutePop.value = true;
    // Wait until PopScope receives canPop=true before issuing the controlled
    // pop; otherwise it would interpret Home as a destructive back action.
    await WidgetsBinding.instance.endOfFrame;

    // A matching route opened after Rating is the root route because Rating
    // uses offAllNamed. In that case Get.back() cannot pop anything and leaves
    // a stopped matching screen visible, which looks like the app is frozen.
    final canPop = Get.key.currentState?.canPop() ?? false;
    if (canPop) {
      Get.back();
    } else {
      Get.offAllNamed(AppRouter.main);
    }
    await Future<void>.delayed(Duration.zero);
    allowRoutePop.value = false;
  }

  Future<void> minimizeSearch() async {
    if (_disposed || _exitInProgress) return;
    if (phase.value != VideoMatchingPhase.preparing &&
        phase.value != VideoMatchingPhase.searching) {
      return;
    }
    if (_sessionCoordinator?.minimize() != true) return;
    await _closeMatchingRoute();
  }

  void restoreMinimizedSearch() {
    if (_disposed) return;
    _sessionCoordinator?.markVisible();
    if (Get.currentRoute == AppRouter.videoMatching) return;
    Future<void>.microtask(() {
      if (_disposed || Get.currentRoute == AppRouter.videoMatching) return;
      Get.toNamed(
        AppRouter.videoMatching,
        arguments: {
          'targetGender': targetGender,
          'anonymousAvatar': anonymousAvatar,
        },
      );
    });
  }

  void _restoreRouteIfMinimized() {
    final coordinator = _sessionCoordinator;
    if (coordinator?.isMinimized.value != true) return;
    restoreMinimizedSearch();
  }

  void _scheduleControllerRelease() {
    _sessionCoordinator?.finish();
    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      if (!Get.isRegistered<VideoMatchingController>()) return;
      final registered = Get.find<VideoMatchingController>();
      if (identical(registered, this)) {
        await Get.delete<VideoMatchingController>(force: true);
      }
    });
  }

  Future<void> _openRoom(String roomId) async {
    if (_handlingRoom || _disposed) return;
    _restoreRouteIfMinimized();
    _sessionCoordinator?.finish();
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

    final peerUid = _otherUid;
    if (peerUid != null && _ratingLoadedForUid != peerUid) {
      _ratingLoadedForUid = peerUid;
      unawaited(_loadOtherRating(peerUid));
    }

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
    if (!cameraToggleInProgress.value) {
      localCameraEnabled.value = cameraStates[uid] == true;
    }

    final mutedStates = Map<String, dynamic>.from(
      data['videoMutedStates'] ?? const <String, dynamic>{},
    );
    remoteMuted.value = mutedStates[otherUid] == true;

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

  Future<void> _loadOtherRating(String peerUid) async {
    try {
      final summary = await _repository.getPeerSummary(peerUid);
      if (!_disposed && _otherUid == peerUid) {
        otherPeerSummary.value = summary;
        otherAvgRating.value =
            summary?.hasRatings == true ? summary!.averageRating : null;
      }
    } catch (error) {
      // Rating is supporting information and must not interrupt a video call.
      debugPrint('Unable to load video peer rating: $error');
    }
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
        _startAudioLevelMeter();
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
    final roomId = _roomId;
    if (roomId == null || _exitInProgress) return;
    final next = !isMuted.value;
    try {
      await _webRTC.setMicrophoneEnabled(!next);
      isMuted.value = next;
      if (next) localVoiceLevel.value = 0;
      await _repository.setMuted(roomId: roomId, uid: uid, muted: next);
    } catch (error) {
      // Never turn the microphone back on after a failed sync. Local privacy
      // takes priority; the next room update/toggle can retry Firestore.
      Get.snackbar(
        videoMatchingTr('Không thể đổi trạng thái micro'),
        videoMatchingTr('Vui lòng thử lại sau một chút.'),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  void _startAudioLevelMeter() {
    if (_audioLevelTimer?.isActive == true) return;
    _stopAudioLevelMeter();
    unawaited(_pollAudioLevels());
    _audioLevelTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(_pollAudioLevels()),
    );
  }

  Future<void> _pollAudioLevels() async {
    if (_pollingAudioLevels || _disposed || _roomId == null) return;
    _pollingAudioLevels = true;
    try {
      final levels = await _webRTC.readAudioLevels();
      if (_disposed || _roomId == null) return;
      _updateVoiceLevel(localVoiceLevel, isMuted.value ? 0 : levels.local);
      _updateVoiceLevel(
        remoteVoiceLevel,
        remoteMuted.value ? 0 : levels.remote,
      );
    } catch (error) {
      debugPrint('Unable to read WebRTC audio levels: $error');
    } finally {
      _pollingAudioLevels = false;
    }
  }

  void _updateVoiceLevel(RxDouble target, double rawLevel) {
    final next =
        rawLevel <= 0.012
            ? 0.0
            : ((rawLevel - 0.012) * 8).clamp(0.0, 1.0).toDouble();
    if ((target.value - next).abs() >= 0.025 || next == 0) {
      target.value = next;
    }
  }

  void _stopAudioLevelMeter() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    _pollingAudioLevels = false;
    localVoiceLevel.value = 0;
    remoteVoiceLevel.value = 0;
  }

  Future<void> toggleCamera() async {
    final roomId = _roomId;
    if (!cameraUnlocked.value ||
        roomId == null ||
        _exitInProgress ||
        cameraToggleInProgress.value) {
      return;
    }

    final previous = localCameraEnabled.value;
    final next = !previous;
    cameraToggleInProgress.value = true;
    try {
      if (next) await _webRTC.ensureLocalVideoTrack();
      if (_disposed || _roomId != roomId) return;
      await _webRTC.setCameraEnabled(next);
      localCameraEnabled.value = next;
      await _repository.setCameraEnabled(
        roomId: roomId,
        uid: uid,
        enabled: next,
      );
    } catch (error) {
      localCameraEnabled.value = previous;
      try {
        await _webRTC.setCameraEnabled(previous);
      } catch (rollbackError) {
        debugPrint('Unable to restore camera state: $rollbackError');
      }
      Get.snackbar(
        videoMatchingTr('Không thể đổi trạng thái camera'),
        videoMatchingTr('Vui lòng thử lại sau một chút.'),
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      cameraToggleInProgress.value = false;
    }
  }

  Future<void> switchCamera() async {
    if (!cameraUnlocked.value ||
        !localCameraEnabled.value ||
        cameraToggleInProgress.value) {
      return;
    }
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
    _stopClock();
    _disconnectTimer?.cancel();
    await _roomSub?.cancel();
    await _callSub?.cancel();
    await _remoteIceSub?.cancel();
    _roomSub = null;
    _callSub = null;
    _remoteIceSub = null;
    // Keep the current call surface until Rating replaces it. The controller
    // release disposes WebRTC after the route transition, avoiding the
    // unnecessary ended screen and a black-frame flash.
    unawaited(
      _webRTC.setMicrophoneEnabled(false).catchError((Object error) {
        debugPrint('Unable to mute ended video room: $error');
      }),
    );
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

    // Rating is best-effort and must not delay the success transition.
    unawaited(_autoRateSuccessfulMatch(roomId: roomId, otherUid: otherUid));
    await _cancelAllSubscriptions();
    if (_disposed) return;

    // Stop captured audio immediately, then release the heavier peer
    // connection after the route animation has had time to render its first
    // frames. Resetting it before navigation caused a visible black-frame jolt.
    unawaited(
      _webRTC.setMicrophoneEnabled(false).catchError((Object error) {
        debugPrint('Unable to mute completed video match: $error');
      }),
    );

    Get.off(
      () => MatchTransitionView(
        tempRoomId: roomId,
        myAvatar: anonymousAvatar,
        otherAvatar: peerAvatar,
      ),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    Future<void>.delayed(const Duration(milliseconds: 320), () async {
      if (_disposed) return;
      await _webRTC.resetConnection();
    });
    Future<void>.delayed(
      const Duration(milliseconds: 700),
      _scheduleControllerRelease,
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
      _scheduleControllerRelease();
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
        _scheduleControllerRelease();
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
    _scheduleControllerRelease();
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
    if (!_disposed) {
      await _closeMatchingRoute();
      _scheduleControllerRelease();
    }
  }

  Future<void> _showConnectionError() async {
    await _fail(StateError('No network connection.'));
  }

  Future<void> _fail(Object error) async {
    if (_disposed || _navigatingToChat || _navigatingToRating) return;
    _restoreRouteIfMinimized();
    _sessionCoordinator?.finish();
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
    remoteMuted.value = false;
    localVoiceLevel.value = 0;
    remoteVoiceLevel.value = 0;
    localCameraEnabled.value = false;
    cameraToggleInProgress.value = false;
    remoteCameraEnabled.value = false;
    hasLiked.value = false;
    otherLiked.value = false;
    otherAnonymousAvatar.value = 'avt_01';
    otherAvgRating.value = null;
    otherPeerSummary.value = null;
    _ratingLoadedForUid = null;
    errorMessage.value = null;
    _handlingRoom = false;
  }

  void _clearRoomIdentity() {
    _roomId = null;
    _otherUid = null;
    _ratingLoadedForUid = null;
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
        _sessionCoordinator?.updateElapsed(searchElapsedSeconds.value);
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
    _stopAudioLevelMeter();
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
    _sessionCoordinator?.finish();
    _stopClock();
    _stopAudioLevelMeter();
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
