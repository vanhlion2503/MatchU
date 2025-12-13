import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/queue_user_model.dart';
import '../../services/chat/matching_service.dart';
import '../auth/auth_controller.dart';

class MatchingController extends GetxController {
  final MatchingService _service = MatchingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final isSearching = false.obs;
  final isMatched = false.obs;

  StreamSubscription<QuerySnapshot>? _roomSub;

  // =========================================================
  // START MATCHING
  // =========================================================
  Future<void> startMatching({required String targetGender}) async {
    if (isSearching.value) return;

    final auth = Get.find<AuthController>();
    final fbUser = auth.user;
    if (fbUser == null) return;

    isSearching.value = true;
    isMatched.value = false;

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
    final roomId = await _service.matchUser(seeker);
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

    isMatched.value = true;
    isSearching.value = false;

    _roomSub?.cancel();
    _roomSub = null;

    // Unlock user khi nhận được room (cho cả user đang match và user đang đợi)
    final user = Get.find<AuthController>().user;
    if (user != null) {
      await _service.forceUnlock(user.uid);
    }

    Get.offNamed("/tempChat", arguments: {"roomId": roomId});
  }

  // =========================================================
  // STOP MATCHING
  // =========================================================
  Future<void> stopMatching() async {
    if (!isSearching.value) return;

    final user = Get.find<AuthController>().user;
    if (user == null) return;

    await _service.dequeue(user.uid);

    await _roomSub?.cancel();
    _roomSub = null;

    isSearching.value = false;
    isMatched.value = false;
  }

  // =========================================================
  // CLEANUP
  // =========================================================
  @override
  void onClose() {
    stopMatching();
    super.onClose();
  }

}
