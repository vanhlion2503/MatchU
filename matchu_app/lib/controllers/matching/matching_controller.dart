import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';

import '../../models/queue_user_model.dart';
import '../../services/chat/matching_service.dart';
import '../auth/auth_controller.dart';

class MatchingController extends GetxController {
  MatchingController();

  final MatchingService _service = MatchingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _dailyMatchingLimit = 10;
  static const String _dailyMatchingCountField = 'dailyMatchingCount';
  static const String _dailyMatchingDateField = 'dailyMatchingDate';
  static const String _matchingRoute = '/matching';

  final isSearching = false.obs;
  final isMatched = false.obs;
  final isMatchingActive = false.obs;
  final isMinimized = false.obs;
  final canCancel = false.obs;

  final targetGender = RxnString();
  final bubbleOffset = Offset(20, 200).obs;

  String? currentSessionId;

  StreamSubscription<QuerySnapshot>? _roomSub;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  final elapsedSeconds = 0.obs;
  Timer? _timer;
  bool _isStartInProgress = false;
  bool _isHandlingMatchFound = false;

  @override
  void onInit() {
    super.onInit();

    _netSub = Connectivity().onConnectivityChanged.listen(_handleConnectivity);
    _cleanupMyOldRooms();
  }

  Future<void> _cleanupMyOldRooms() async {
    final uid = Get.find<AuthController>().user?.uid;
    if (uid == null) return;

    final snaps =
        await _firestore
            .collection('tempChats')
            .where('participants', arrayContains: uid)
            .where('status', isEqualTo: 'active')
            .get();

    for (final doc in snaps.docs) {
      await doc.reference.update({
        'status': 'ended',
        'endedReason': 'app_restarted',
        'endedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _handleConnectivity(List<ConnectivityResult> results) async {
    final isOffline = results.contains(ConnectivityResult.none);
    if (!isOffline || !isSearching.value) return;

    await _roomSub?.cancel();
    _roomSub = null;

    Get.snackbar(
      'Mất kết nối',
      'Đã mất mạng, quay về trang tìm chat',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );

    await stopMatching();
    Get.offAllNamed('/main');
  }

  void startTimer() {
    _timer?.cancel();
    elapsedSeconds.value = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value++;
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _dateKey(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  MatchingQuotaPreview _buildQuotaPreviewFromData(Map<String, dynamic> data) {
    final isFaceVerified = _parseBool(data['isFaceVerified']);
    if (isFaceVerified) {
      return const MatchingQuotaPreview(
        isUnlimited: true,
        used: 0,
        remaining: -1,
        limit: _dailyMatchingLimit,
      );
    }

    final today = _dateKey(DateTime.now());
    final savedDay = data[_dailyMatchingDateField]?.toString();
    final used =
        savedDay == today ? _parseInt(data[_dailyMatchingCountField]) : 0;
    final remaining = (_dailyMatchingLimit - used).clamp(
      0,
      _dailyMatchingLimit,
    );

    return MatchingQuotaPreview(
      isUnlimited: false,
      used: used,
      remaining: remaining,
      limit: _dailyMatchingLimit,
    );
  }

  Future<MatchingQuotaPreview?> getDailyQuotaPreview() async {
    final uid = Get.find<AuthController>().user?.uid;
    if (uid == null) return null;

    final snap = await _firestore.collection('users').doc(uid).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? <String, dynamic>{};
    return _buildQuotaPreviewFromData(data);
  }

  Future<bool> _consumeQuotaOnSuccessfulMatch(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    return _firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return false;

      final data = snap.data() ?? <String, dynamic>{};
      final quota = _buildQuotaPreviewFromData(data);
      if (quota.isUnlimited) return true;
      if (quota.remaining <= 0) return false;

      final nextCount = quota.used + 1;
      tx.set(userRef, {
        _dailyMatchingCountField: nextCount,
        _dailyMatchingDateField: _dateKey(DateTime.now()),
      }, SetOptions(merge: true));

      return true;
    });
  }

  void _resetMatchingState() {
    stopTimer();
    elapsedSeconds.value = 0;
    currentSessionId = null;
    isSearching.value = false;
    isMatched.value = false;
    isMatchingActive.value = false;
    isMinimized.value = false;
    canCancel.value = false;
  }

  // =========================================================
  // START MATCHING
  // =========================================================
  Future<void> startMatching({required String targetGender}) async {
    if (isSearching.value || _isStartInProgress) return;
    _isStartInProgress = true;

    try {
      final auth = Get.find<AuthController>();
      final fbUser = auth.user;
      if (fbUser == null) return;

      final anonAvatarC = Get.find<AnonymousAvatarController>();
      final myAnonAvatar = anonAvatarC.selectedAvatar.value;
      if (myAnonAvatar == null) {
        Get.snackbar(
          'Thiếu avatar ẩn danh',
          'Vui lòng chọn avatar trước khi tìm chat',
        );
        return;
      }

      final profileSnap =
          await _firestore.collection('users').doc(fbUser.uid).get();
      if (!profileSnap.exists) {
        Get.snackbar('Lỗi', 'Không tìm thấy thông tin tài khoản.');
        return;
      }

      final data = profileSnap.data()!;
      final quota = _buildQuotaPreviewFromData(data);
      if (!quota.isUnlimited && quota.remaining <= 0) {
        if (Get.currentRoute == _matchingRoute) {
          Future.microtask(() {
            if (Get.currentRoute == _matchingRoute) {
              Get.back();
            }
          });
        }
        return;
      }

      currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final sessionId = currentSessionId!;

      this.targetGender.value = targetGender;
      isMatchingActive.value = true;
      canCancel.value = false;
      startTimer();
      Future.delayed(const Duration(seconds: 1), () {
        if (isSearching.value && !isMatched.value) {
          canCancel.value = true;
        }
      });

      isSearching.value = true;
      isMatched.value = false;
      isMinimized.value = false;

      final seeker = QueueUserModel(
        uid: fbUser.uid,
        gender: (data['gender'] ?? 'random').toString(),
        targetGender: targetGender,
        sessionId: sessionId,
        avgChatRating: 0,
        interests: const [],
        createdAt: DateTime.now(),
      );

      final roomId = await _service.matchUser(
        seeker,
        myAnonymousAvatar: myAnonAvatar,
        sessionId: sessionId,
      );
      if (roomId != null) {
        _go(roomId);
        return;
      }

      await _roomSub?.cancel();
      _roomSub = _firestore
          .collection('tempChats')
          .where('sessionIds', arrayContains: sessionId)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen((snapshot) {
            for (final doc in snapshot.docs) {
              final room = doc.data();
              if (room['sessionA'] == sessionId ||
                  room['sessionB'] == sessionId) {
                _go(doc.id);
                break;
              }
            }
          });
    } catch (_) {
      await _roomSub?.cancel();
      _roomSub = null;
      _resetMatchingState();

      final uid = Get.find<AuthController>().user?.uid;
      if (uid != null) {
        await _service.forceUnlock(uid);
      }

      Get.snackbar(
        'Không thể bắt đầu matching',
        'Vui lòng thử lại sau ít phút.',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      _isStartInProgress = false;
    }
  }

  // =========================================================
  // NAVIGATE TO ROOM
  // =========================================================
  void _go(String roomId) async {
    if (isMatched.value || _isHandlingMatchFound) return;
    _isHandlingMatchFound = true;

    try {
      final user = Get.find<AuthController>().user;
      if (user != null) {
        final consumed = await _consumeQuotaOnSuccessfulMatch(user.uid);
        if (!consumed) {
          await _firestore.collection('tempChats').doc(roomId).set({
            'status': 'ended',
            'endedBy': user.uid,
            'endedReason': 'daily_matching_limit_reached',
            'endedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await _service.forceUnlock(user.uid);
          await stopMatching();

          if (Get.currentRoute == _matchingRoute) {
            Get.back();
          }
          return;
        }
      }

      stopTimer();

      isMatched.value = true;
      isSearching.value = false;
      isMatchingActive.value = false;
      isMinimized.value = false;
      canCancel.value = false;

      await _roomSub?.cancel();
      _roomSub = null;

      if (user != null) {
        await _service.forceUnlock(user.uid);
      }

      await Future.delayed(const Duration(milliseconds: 1500));
      Get.offNamed('/tempChat', arguments: {'roomId': roomId});
    } finally {
      if (!isMatched.value) {
        _isHandlingMatchFound = false;
      }
    }
  }

  // =========================================================
  // STOP MATCHING
  // =========================================================
  Future<void> stopMatching() async {
    final wasSearching = isSearching.value;

    stopTimer();
    elapsedSeconds.value = 0;

    await _roomSub?.cancel();
    _roomSub = null;
    currentSessionId = null;
    isSearching.value = false;
    isMatched.value = false;
    isMatchingActive.value = false;
    isMinimized.value = false;
    canCancel.value = false;

    if (!wasSearching) return;

    final user = Get.find<AuthController>().user;
    if (user == null) return;

    await _service.dequeue(user.uid);
  }

  // =========================================================
  // CLEANUP
  // =========================================================
  @override
  void onClose() {
    _netSub?.cancel();
    stopMatching();
    stopTimer();
    super.onClose();
  }
}

class MatchingQuotaPreview {
  final bool isUnlimited;
  final int used;
  final int remaining;
  final int limit;

  const MatchingQuotaPreview({
    required this.isUnlimited,
    required this.used,
    required this.remaining,
    required this.limit,
  });
}
