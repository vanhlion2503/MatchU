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
      avgChatRating: 0,
      interests: const [],
      createdAt: DateTime.now(),
    );

    // 1️⃣ Try match immediately
    final roomId = await _service.matchUser(seeker, myAnonymousAvatar: myAnonAvatar,);
    if (roomId != null) {
      _go(roomId);
      return;
    }

    // 2️⃣ Wait for room
    _roomSub = _firestore
      .collection("tempChats")
      .where("participants", arrayContains: fbUser.uid)
      .where("status", isEqualTo: "active")
      .snapshots()
      .listen((snapshot) {
    if (snapshot.docs.isEmpty) return;

    _go(snapshot.docs.first.id);
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
    if (!isSearching.value) return;
    stopTimer();
    final user = Get.find<AuthController>().user;
    if (user == null) return;

    await _service.dequeue(user.uid);

    await _roomSub?.cancel();
    _roomSub = null;

    isSearching.value = false;
    isMatched.value = false;
    isMatchingActive.value = false;
    canCancel.value = false;

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
