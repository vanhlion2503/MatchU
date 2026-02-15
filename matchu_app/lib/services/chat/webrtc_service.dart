import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef IceCandidateCallback = Future<void> Function(RTCIceCandidate candidate);
typedef PeerConnectionStateCallback =
    void Function(RTCPeerConnectionState state);

class WebRTCService {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _renderersInitialized = false;

  Future<void> initPeerConnection({
    required bool withVideo,
    required IceCandidateCallback onIceCandidate,
    required PeerConnectionStateCallback onConnectionStateChanged,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    await initRenderers();
    await resetConnection();

    _localStream = await _getUserMedia(withVideo: withVideo);
    localRenderer.srcObject = _localStream;

    _peerConnection = await _createPeerConnection(
      onIceCandidate: onIceCandidate,
      onConnectionStateChanged: onConnectionStateChanged,
      iceServers: iceServers,
    );

    final stream = _localStream;
    final peer = _peerConnection;
    if (stream == null || peer == null) return;

    for (final track in stream.getTracks()) {
      await peer.addTrack(track, stream);
    }
  }

  Future<void> initRenderers() async {
    if (_renderersInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersInitialized = true;
  }

  Future<MediaStream> _getUserMedia({required bool withVideo}) {
    return navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video':
          withVideo
              ? <String, dynamic>{
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 24},
              }
              : false,
    });
  }

  Future<RTCPeerConnection> _createPeerConnection({
    required IceCandidateCallback onIceCandidate,
    required PeerConnectionStateCallback onConnectionStateChanged,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    const defaultIceServers = <Map<String, String>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];

    final config = <String, dynamic>{
      'sdpSemantics': 'unified-plan',
      'iceServers':
          (iceServers != null && iceServers.isNotEmpty)
              ? iceServers
              : defaultIceServers,
    };

    final peer = await createPeerConnection(config);

    // Push local ICE candidates to Firestore signaling as soon as they appear.
    peer.onIceCandidate = (candidate) {
      final c = candidate.candidate;
      if (c == null || c.isEmpty) return;
      unawaited(onIceCandidate(candidate));
    };

    peer.onConnectionState = onConnectionStateChanged;

    // Bind the first remote stream to renderer for call UI.
    peer.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        return;
      }

      final remote = remoteRenderer.srcObject;
      if (remote != null) {
        remote.addTrack(event.track);
      }
    };

    return peer;
  }

  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    final peer = _requirePeerConnection();
    final withVideo = (_localStream?.getVideoTracks().isNotEmpty ?? false);
    final offer = await peer.createOffer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': withVideo,
      'iceRestart': iceRestart,
    });
    await peer.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final peer = _requirePeerConnection();
    final withVideo = (_localStream?.getVideoTracks().isNotEmpty ?? false);
    final answer = await peer.createAnswer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': withVideo,
    });
    await peer.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(Map<String, dynamic> descriptionMap) async {
    final sdp = descriptionMap['sdp'];
    final type = descriptionMap['type'];
    if (sdp is! String || type is! String || sdp.isEmpty || type.isEmpty) {
      throw StateError('Invalid remote session description.');
    }

    await _requirePeerConnection().setRemoteDescription(
      RTCSessionDescription(sdp, type),
    );
  }

  Future<void> addRemoteIceCandidate(Map<String, dynamic> candidateMap) async {
    final candidateValue = candidateMap['candidate'];
    final sdpMidValue = candidateMap['sdpMid'];
    final sdpMLineIndexValue = candidateMap['sdpMLineIndex'];

    if (candidateValue is! String || candidateValue.isEmpty) return;

    final candidate = RTCIceCandidate(
      candidateValue,
      sdpMidValue is String ? sdpMidValue : null,
      sdpMLineIndexValue is num ? sdpMLineIndexValue.toInt() : null,
    );

    await _requirePeerConnection().addCandidate(candidate);
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    final stream = _localStream;
    if (stream == null) return;

    for (final track in stream.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final stream = _localStream;
    if (stream == null) return;

    for (final track in stream.getVideoTracks()) {
      track.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final stream = _localStream;
    if (stream == null) return;

    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;

    await Helper.switchCamera(tracks.first);
  }

  Future<void> restartIce() async {
    await _requirePeerConnection().restartIce();
  }

  Future<void> resetConnection() async {
    try {
      final peer = _peerConnection;
      _peerConnection = null;
      if (peer != null) {
        await peer.close();
      }
    } catch (error) {
      debugPrint('WebRTC close peer error: $error');
    }

    try {
      remoteRenderer.srcObject = null;
      localRenderer.srcObject = null;

      final local = _localStream;
      _localStream = null;
      if (local != null) {
        for (final track in local.getTracks()) {
          track.stop();
        }
        await local.dispose();
      }
    } catch (error) {
      debugPrint('WebRTC local stream dispose error: $error');
    }
  }

  Future<void> disposeAll() async {
    await resetConnection();

    if (_renderersInitialized) {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      _renderersInitialized = false;
    }
  }

  RTCPeerConnection _requirePeerConnection() {
    final peer = _peerConnection;
    if (peer == null) {
      throw StateError('Peer connection is not initialized.');
    }
    return peer;
  }
}
