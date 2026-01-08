import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/chat/chat_service.dart';

class UnreadController extends GetxController {
  final ChatService _service = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxInt totalUnread = 0.obs;
  StreamSubscription<int>? _sub;

  @override
  void onInit() {
    super.onInit();

    /// ✅ 1. CHECK USER NGAY LÚC INIT
    final user = _auth.currentUser;
    if (user != null) {
      _bindUnread();
    }

    /// ✅ 2. LISTEN AUTH CHANGES
    _auth.authStateChanges().listen((user) {
      _sub?.cancel();

      if (user == null) {
        totalUnread.value = 0;
        return;
      }

      _bindUnread();
    });
  }

  void _bindUnread() {
    _sub?.cancel();

    _sub = _service.listenTotalUnread().listen((count) {
      totalUnread.value = count;
    });
  }

  // ====================================================
  // 🔥 CLEANUP FOR LOGOUT
  // ====================================================
  void cleanup() {
    _sub?.cancel();
    _sub = null;
    totalUnread.value = 0;
  }

  @override
  void onClose() {
    cleanup();
    super.onClose();
  }
}

