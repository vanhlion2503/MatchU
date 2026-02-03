import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


import '../../models/queue_user_model.dart';
import '../../services/chat/matching_service.dart';
import '../auth/auth_controller.dart';

class MatchingController extends GetxController{
  final MatchingService _service = MatchingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  @override
  void onInit() {
    super.onInit();

    _netSub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      _handleConnectivity(results);
    });
    _cleanupMyOldRooms();
  }

  Future<void> _cleanupMyOldRooms() async {
    final uid = Get.find<AuthController>().user?.uid;
    if (uid == null) return;

    final snaps = await _firestore
        .collection("tempChats")
        .where("participants", arrayContains: uid)
        .where("status", isEqualTo: "active")
        .get();

    for (final doc in snaps.docs) {
      await doc.reference.update({
        "status": "ended",
        "endedReason": "app_restarted",
        "endedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  void _handleConnectivity(List<ConnectivityResult> results) async {
    final isOffline = results.contains(ConnectivityResult.none);

    if (isOffline && isSearching.value) {
      // ❗ Hủy listener sớm để tránh log Firestore
      await _roomSub?.cancel();
      _roomSub = null;

      Get.snackbar(
        "Mất kết nối",
        "Đã mất mạng, quay về trang tìm chat",
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );

      await stopMatching();

      Get.offAllNamed("/main");
    }
  }

  void startTimer(){
    _timer?.cancel();
    elapsedSeconds.value =0;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        elapsedSeconds.value++;
      },
    );
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // =========================================================
  // START MATCHING
  // =========================================================
  Future<void> startMatching({required String targetGender}) async {
    if (isSearching.value) return;

    final anonAvatarC = Get.find<AnonymousAvatarController>();
    final myAnonAvatar = anonAvatarC.selectedAvatar.value;

    if (myAnonAvatar == null) {
      Get.snackbar(
        "Thiếu avatar ẩn danh",
        "Vui lòng chọn avatar trước khi tìm chat",
      );
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
    final auth = Get.find<AuthController>();
    final fbUser = auth.user;
    if (fbUser == null) return;

    isSearching.value = true;
    isMatched.value = false;
    isMinimized.value = false;

    // Load profile
    final snap =
        await _firestore.collection("users").doc(fbUser.uid).get();
    if (!snap.exists) {
      isSearching.value = false;
      return;
    }

    final data = snap.data()!;

    final seeker = QueueUserModel(
      uid: fbUser.uid,
      gender: data["gender"],
      targetGender: targetGender,
      sessionId: sessionId,
      avgChatRating: 0,
      interests: const [],
      createdAt: DateTime.now(),
    );

    // 1️⃣ Try match immediately
    final roomId = await _service.matchUser(
      seeker,
      myAnonymousAvatar: myAnonAvatar,
      sessionId: sessionId,
    );
    if (roomId != null) {
      _go(roomId);
      return;
    }
    _roomSub?.cancel();

    _roomSub = _firestore
        .collection("tempChats")
        .where("sessionIds", arrayContains: sessionId)
        .where("status", isEqualTo: "active")
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final room = doc.data();

        if (room["sessionA"] == sessionId ||
            room["sessionB"] == sessionId) {
          _go(doc.id);
          break;
        }
      }
    });

  }

  // =========================================================
  // NAVIGATE TO ROOM
  // =========================================================
  void _go(String roomId) async {
    if (isMatched.value) return;

    stopTimer();

    isMatched.value = true;
    isSearching.value = false;
    isMatchingActive.value = false;
    isMinimized.value = false;
    canCancel.value = false;


    _roomSub?.cancel();
    _roomSub = null;

    final user = Get.find<AuthController>().user;
    if (user != null) {
      await _service.forceUnlock(user.uid);
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    
    Get.offNamed("/tempChat", arguments: {"roomId": roomId});
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
