import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/services/auth/auth_service.dart';
import 'package:matchu_app/services/security/identity_key_service.dart';

class AuthGateController extends GetxController {
  final AuthService _auth = AuthService();
  final _box = GetStorage();

  StreamSubscription<User?>? _sub;
  bool _navigated = false;

  @override
  void onReady() {
    super.onReady();

    // 🔥 Lắng nghe auth state DUY NHẤT 1 LẦN
    _sub = _auth.authStateChanges.listen(_handleAuth);
  }

  /// ============================
  /// CORE AUTH FLOW
  /// ============================
  Future<void> _handleAuth(User? user) async {
    // ⛔ UI chưa sẵn sàng → đợi
    await _waitForContext();

    // ============================
    // 1️⃣ CHƯA LOGIN
    // ============================
    if (user == null) {
      _navigated = false;
      _box.remove('isRegistering');
      Get.offAllNamed('/welcome');
      return;
    }

    // Ensure Firestore network is re-enabled after logout.
    try {
      await FirebaseFirestore.instance.enableNetwork();
    } catch (_) {}

    final isRegistering = _box.read('isRegistering') == true;
    if (isRegistering) {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
      final currentRoute = Get.currentRoute;

      if (!refreshedUser.emailVerified) {
        if (currentRoute != '/verify-email') {
          Get.offAllNamed('/verify-email');
        }
        return;
      }

      final enrolledFactors =
          await refreshedUser.multiFactor.getEnrolledFactors();
      final hasMfa = enrolledFactors.isNotEmpty;
      if (!hasMfa) {
        if (currentRoute != '/enroll-phone' && currentRoute != '/otp-enroll') {
          Get.offAllNamed('/enroll-phone');
        }
        return;
      }
      _box.remove('isRegistering');
    }

    await user.getIdToken(true);
    await Future.delayed(const Duration(milliseconds: 300));

    // ============================
    // 2️⃣ ĐÃ LOGIN NHƯNG ĐÃ NAVIGATE
    // ============================
    if (_navigated) return;
    _navigated = true;

    // ============================
    // 3️⃣ INIT SECURITY (E2EE, IDENTITY KEY…)
    // ============================
    await IdentityKeyService.generateIfNotExists();

    // ============================
    // 4️⃣ LOAD USER DOCUMENT
    // ============================
    final snap = await _loadUserDoc(user.uid);

    // ❌ CHƯA CÓ PROFILE → COMPLETE
    if (!snap.exists) {
      Get.offAllNamed('/complete-profile');
      return;
    }

    final data = snap.data()!;
    final completed = data['isProfileCompleted'] == true;

    // ============================
    // 5️⃣ ROUTE CUỐI CÙNG
    // ============================
    Get.offAllNamed(completed ? '/main' : '/complete-profile');
  }

  /// ============================
  /// UTILITIES
  /// ============================

  /// Đợi UI + Navigator sẵn sàng
  Future<void> _waitForContext() async {
    while (Get.context == null) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  /// Retry load Firestore user doc (tránh race condition)
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUserDoc(
    String uid,
  ) async {
    for (int i = 0; i < 3; i++) {
      final snap = await _auth.db.collection('users').doc(uid).get();
      if (snap.exists) return snap;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return await _auth.db.collection('users').doc(uid).get();
  }

  /// ============================
  /// RESET KHI LOGOUT
  /// ============================
  void reset() {
    _navigated = false;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
