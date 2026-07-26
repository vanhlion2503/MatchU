import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/models/matching/matching_mode.dart';
import 'package:matchu_app/models/account_access/account_access_model.dart';
import 'package:matchu_app/models/matching/matching_reputation_policy.dart';
import 'package:matchu_app/translations/matching_chat_translations.dart';

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
  static const Set<String> _verifiedStatuses = {
    'verified',
    'approved',
    'passed',
    'success',
    'completed',
    'complete',
    'done',
  };

  final isSearching = false.obs;
  final isMatched = false.obs;
  final isMatchingActive = false.obs;
  final isMinimized = false.obs;
  final canCancel = false.obs;

  final targetGender = RxnString();
  final bubbleOffset = Offset(20, 200).obs;

  String? currentSessionId;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  final elapsedSeconds = 0.obs;
  Timer? _timer;
  bool _isStartInProgress = false;
  bool _isHandlingMatchFound = false;

  @override
  void onInit() {
    super.onInit();

    _netSub = Connectivity().onConnectivityChanged.listen(_handleConnectivity);
  }

  void _handleConnectivity(List<ConnectivityResult> results) async {
    final isOffline = results.contains(ConnectivityResult.none);
    if (!isOffline || !isSearching.value) return;

    await _roomSub?.cancel();
    _roomSub = null;

    Get.snackbar(
      matchingChatTr('Mất kết nối'),
      matchingChatTr('Đã mất mạng, quay về trang tìm chat'),
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

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  String _normalizeStatus(dynamic value) {
    return (value?.toString() ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
  }

  bool _isVerifiedStatus(dynamic value) {
    final normalized = _normalizeStatus(value);
    if (normalized.isEmpty) return false;
    return _verifiedStatuses.contains(normalized);
  }

  bool _hasAnyTruthyFlag(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (_parseBool(data[key])) {
        return true;
      }
    }
    return false;
  }

  bool _hasAnyVerifiedStatus(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (_isVerifiedStatus(data[key])) {
        return true;
      }
    }
    return false;
  }

  bool _hasAnyNonNull(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data[key] != null) {
        return true;
      }
    }
    return false;
  }

  bool _isAccountVerified(Map<String, dynamic> data) {
    if (_hasAnyTruthyFlag(data, const [
      'isFaceVerified',
      'isVerified',
      'verified',
      'isAccountVerified',
      'accountVerified',
      'identityVerified',
      'isIdentityVerified',
      'kycVerified',
      'isKycVerified',
    ])) {
      return true;
    }

    if (_hasAnyVerifiedStatus(data, const [
      'verificationStatus',
      'accountVerificationStatus',
      'identityVerificationStatus',
      'faceVerificationStatus',
      'accountStatus',
    ])) {
      return true;
    }

    if (_hasAnyNonNull(data, const [
      'faceVerifiedAt',
      'verifiedAt',
      'accountVerifiedAt',
      'identityVerifiedAt',
    ])) {
      return true;
    }

    final verification = _asStringDynamicMap(data['verification']);
    if (verification != null) {
      if (_hasAnyTruthyFlag(verification, const [
        'isVerified',
        'verified',
        'isFaceVerified',
        'accountVerified',
        'identityVerified',
      ])) {
        return true;
      }

      if (_hasAnyVerifiedStatus(verification, const ['status', 'state'])) {
        return true;
      }

      if (_hasAnyNonNull(verification, const [
        'verifiedAt',
        'faceVerifiedAt',
        'accountVerifiedAt',
      ])) {
        return true;
      }
    }

    return false;
  }

  MatchingQuotaPreview _buildQuotaPreviewFromData(Map<String, dynamic> data) {
    final reputationScore = MatchingReputationPolicy.scoreFrom(
      data['reputationScore'],
    );
    if (_isAccountVerified(data)) {
      return MatchingQuotaPreview(
        isUnlimited: true,
        used: 0,
        remaining: -1,
        limit: _dailyMatchingLimit,
        reputationScore: reputationScore,
        gem: _parseInt(data['gem'], fallback: 15).clamp(0, 1 << 31).toInt(),
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
      reputationScore: reputationScore,
      gem: _parseInt(data['gem'], fallback: 15).clamp(0, 1 << 31).toInt(),
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

  void _resetMatchingState() {
    stopTimer();
    elapsedSeconds.value = 0;
    currentSessionId = null;
    isSearching.value = false;
    isMatched.value = false;
    isMatchingActive.value = false;
    isMinimized.value = false;
    canCancel.value = false;
    _isHandlingMatchFound = false;
  }

  // =========================================================
  // START MATCHING
  // =========================================================
  Future<void> startMatching({required String targetGender}) async {
    if (isSearching.value || _isStartInProgress) return;
    _isStartInProgress = true;
    _isHandlingMatchFound = false;

    try {
      final auth = Get.find<AuthController>();
      final fbUser = auth.user;
      if (fbUser == null) return;

      final anonAvatarC = Get.find<AnonymousAvatarController>();
      final myAnonAvatar = anonAvatarC.selectedAvatar.value;
      if (myAnonAvatar == null) {
        Get.snackbar(
          matchingChatTr('Thiếu avatar ẩn danh'),
          matchingChatTr('Vui lòng chọn avatar trước khi tìm chat'),
        );
        return;
      }

      final profileSnap =
          await _firestore.collection('users').doc(fbUser.uid).get();
      if (!profileSnap.exists) {
        Get.snackbar(
          MatchingChatTranslationKeys.error.tr,
          matchingChatTr('Không tìm thấy thông tin tài khoản.'),
        );
        return;
      }

      final data = profileSnap.data()!;
      final reputationScore = MatchingReputationPolicy.scoreFrom(
        data['reputationScore'],
      );
      if (!MatchingReputationPolicy.canUse(
        MatchingMode.chat,
        reputationScore,
      )) {
        Get.snackbar(
          MatchingChatTranslationKeys.insufficientReputationTitle.tr,
          MatchingChatTranslationKeys.tempChatReputationRequired.trParams({
            'required':
                MatchingReputationPolicy.minimumTempChatScore.toString(),
            'score': reputationScore.toString(),
          }),
          snackPosition: SnackPosition.TOP,
        );
        if (Get.currentRoute == _matchingRoute) {
          Future.microtask(() {
            if (Get.currentRoute == _matchingRoute) {
              Get.back();
            }
          });
        }
        return;
      }

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
      _roomSub = _service.listenSession(fbUser.uid).listen((snapshot) {
        final queue = snapshot.data();
        if (queue == null || queue['sessionId'] != sessionId) return;
        if (queue['status'] == 'matched' && queue['roomId'] is String) {
          _go(queue['roomId'] as String);
        }
      });
    } catch (error) {
      await _roomSub?.cancel();
      _roomSub = null;
      _resetMatchingState();

      final uid = Get.find<AuthController>().user?.uid;
      if (uid != null) {
        try {
          await _service.forceUnlock(uid);
        } catch (_) {
          // The server queue expires automatically; keep the original error.
        }
      }

      if (_showReputationError(error, MatchingMode.chat)) return;

      Get.snackbar(
        matchingChatTr('Không thể bắt đầu matching'),
        matchingChatTr(
          error is AccountAccessException
              ? error.message
              : 'Vui lòng thử lại sau ít phút.',
        ),
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      _isStartInProgress = false;
    }
  }

  bool _showReputationError(Object error, MatchingMode mode) {
    if (error is! FirebaseFunctionsException ||
        error.code != 'failed-precondition') {
      return false;
    }
    final details = error.details;
    if (details is! Map || details['reason'] != 'insufficient-reputation') {
      return false;
    }

    final score = MatchingReputationPolicy.scoreFrom(
      details['currentReputation'],
    );
    final messageKey =
        mode == MatchingMode.video
            ? MatchingChatTranslationKeys.videoReputationRequired
            : MatchingChatTranslationKeys.tempChatReputationRequired;
    Get.snackbar(
      MatchingChatTranslationKeys.insufficientReputationTitle.tr,
      messageKey.trParams({
        'required': MatchingReputationPolicy.minimumScoreFor(mode).toString(),
        'score': score.toString(),
      }),
      snackPosition: SnackPosition.TOP,
    );
    return true;
  }

  // =========================================================
  // NAVIGATE TO ROOM
  // =========================================================
  void _go(String roomId) async {
    if (isMatched.value || _isHandlingMatchFound) return;
    _isHandlingMatchFound = true;

    try {
      stopTimer();

      isMatched.value = true;
      isSearching.value = false;
      isMatchingActive.value = false;
      isMinimized.value = false;
      canCancel.value = false;

      await _roomSub?.cancel();
      _roomSub = null;

      await Future.delayed(const Duration(milliseconds: 450));
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
    final sessionId = currentSessionId;
    currentSessionId = null;
    isSearching.value = false;
    isMatched.value = false;
    isMatchingActive.value = false;
    isMinimized.value = false;
    canCancel.value = false;
    _isHandlingMatchFound = false;

    if (!wasSearching) return;

    final user = Get.find<AuthController>().user;
    if (user == null) return;

    try {
      await _service.dequeue(user.uid, sessionId: sessionId);
    } catch (_) {
      // UI stops immediately; the server expires an abandoned queue session.
    }
  }

  // =========================================================
  // CLEANUP
  // =========================================================
  @override
  void onClose() {
    _netSub?.cancel();
    unawaited(stopMatching());
    stopTimer();
    super.onClose();
  }
}

class MatchingQuotaPreview {
  final bool isUnlimited;
  final int used;
  final int remaining;
  final int limit;
  final int reputationScore;
  final int gem;

  const MatchingQuotaPreview({
    required this.isUnlimited,
    required this.used,
    required this.remaining,
    required this.limit,
    required this.reputationScore,
    required this.gem,
  });

  bool canUse(MatchingMode mode) {
    return MatchingReputationPolicy.canUse(mode, reputationScore);
  }
}
