import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/queue_user_model.dart';
import '../../services/chat/matching_service.dart';
import '../auth/auth_controller.dart';

class MatchingController extends GetxController {
  final MatchingService _matchingService = MatchingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final isSearching = false.obs;
  final isMatched = false.obs;
  final currentRoomId = RxnString();

  StreamSubscription? _roomListener;

  // =========================================================
  // START MATCHING
  // =========================================================
  Future<void> startMatching({
    required String targetGender,
  }) async {
    if (isSearching.value) return;

    final auth = Get.find<AuthController>();
    final fbUser = auth.user; // 🔥 FIX 1
    if (fbUser == null) return;

    /// 🔥 FIX 2: load hồ sơ user từ Firestore
    final userSnap =
        await _firestore.collection("users").doc(fbUser.uid).get();

    if (!userSnap.exists) {
      Get.snackbar("Lỗi", "Không tìm thấy hồ sơ người dùng");
      return;
    }

    final data = userSnap.data()!;

    isSearching.value = true;
    isMatched.value = false;
    currentRoomId.value = null;

    final seeker = QueueUserModel(
      uid: fbUser.uid,
      gender: data["gender"],
      targetGender: targetGender,
      avgChatRating: (data["avgChatRating"] ?? 0).toDouble(),
      interests: List<String>.from(data["interests"] ?? []),
      createdAt: DateTime.now(),
    );

    print("🔍 START MATCHING: ${seeker.uid}");

    /// 1️⃣ Try match immediately
    final roomId = await _matchingService.matchUser(seeker);

    if (roomId != null) {
      _onMatched(roomId);
      return;
    }

    /// 2️⃣ Not matched → listen for room
    _listenForRoom(seeker.uid);
  }


  // =========================================================
  // STOP MATCHING (USER CANCEL)
  // =========================================================
  Future<void> stopMatching() async {
    if (!isSearching.value) return;

    final user = Get.find<AuthController>().user;
    if (user == null) return;

    print("🛑 STOP MATCHING: ${user.uid}");

    await _matchingService.dequeue(user.uid);

    await _roomListener?.cancel();
    _roomListener = null;

    isSearching.value = false;
    isMatched.value = false;
    currentRoomId.value = null;
  }

  // =========================================================
  // LISTEN FOR ROOM CREATION
  // =========================================================
  void _listenForRoom(String uid) {
    print("👂 LISTEN tempChats for $uid");

    _roomListener = _firestore
        .collection("tempChats")
        .where(Filter.or(
          Filter("userA", isEqualTo: uid),
          Filter("userB", isEqualTo: uid),
        ))
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      final roomId = doc.id;

      print("💘 ROOM FOUND: $roomId");
      _onMatched(roomId);
    });
  }

  // =========================================================
  // MATCH SUCCESS HANDLER
  // =========================================================
  Future<void> _onMatched(String roomId) async {
    if (isMatched.value) return;

    print("🎉 MATCHED → room $roomId");

    isMatched.value = true;
    isSearching.value = false;
    currentRoomId.value = roomId;

    await _roomListener?.cancel();
    _roomListener = null;

    /// Điều hướng sang màn chat
    Get.offNamed(
      "/tempChat",
      arguments: {"roomId": roomId},
    );
  }

  // =========================================================
  // CLEANUP
  // =========================================================
  @override
  void onClose() {
    _roomListener?.cancel();
    super.onClose();
  }
}
