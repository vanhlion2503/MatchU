import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/auth/auth_service.dart';
import 'package:matchu_app/services/security/identity_key_service.dart';

class AuthGateController extends GetxController {
  final AuthService _auth = AuthService();
  final _box = GetStorage();

  StreamSubscription<User?>? _sub;
  bool _navigated = false;
  bool _isLoggingOut = false;
  int _authEventToken = 0;
  String? _signedOutRedirectRoute;
  DateTime? _logoutSplashShownAt;

  static const _minimumSplashDuration = Duration(milliseconds: 700);

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
    final eventToken = ++_authEventToken;

    // ⛔ UI chưa sẵn sàng → đợi
    await _waitForContext();
    if (eventToken != _authEventToken) return;

    // ============================
    // 1️⃣ CHƯA LOGIN
    // ============================
    if (_isLoggingOut && user != null) {
      return;
    }

    if (user == null) {
      final redirectRoute = _signedOutRedirectRoute ?? AppRouter.welcome;
      await _holdSplashBeforeSignedOutRedirect(redirectRoute);
      if (eventToken != _authEventToken) return;

      if (FirebaseAuth.instance.currentUser != null) {
        return;
      }

      _navigated = false;
      _isLoggingOut = false;
      _signedOutRedirectRoute = null;
      _logoutSplashShownAt = null;
      _box.remove('isRegistering');
      _box.remove('isPhoneSignInResolving');
      if (Get.currentRoute != redirectRoute) {
        Get.offAllNamed(redirectRoute);
      }
      return;
    }

    if (_box.read('isPhoneSignInResolving') == true) {
      return;
    }

    // Ensure Firestore network is re-enabled after logout.
    try {
      await FirebaseFirestore.instance.enableNetwork();
    } catch (_) {}

    final isRegistering = _box.read('isRegistering') == true;
    if (isRegistering) {
      await user.reload();
      if (eventToken != _authEventToken) return;

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
      final hasVerifiedPhone = enrolledFactors.any(
        (factor) => factor is PhoneMultiFactorInfo,
      );
      if (!hasVerifiedPhone) {
        if (currentRoute != '/enroll-phone' && currentRoute != '/otp-enroll') {
          Get.offAllNamed('/enroll-phone');
        }
        return;
      }
      _box.remove('isRegistering');
    }

    await user.getIdToken(true);
    await Future.delayed(const Duration(milliseconds: 300));

    if (eventToken != _authEventToken ||
        _isLoggingOut ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }

    // ============================
    // 2️⃣ ĐÃ LOGIN NHƯNG ĐÃ NAVIGATE
    // ============================
    if (_navigated) return;
    _navigated = true;

    // ============================
    // 3️⃣ INIT SECURITY (E2EE, IDENTITY KEY…)
    // ============================
    try {
      await IdentityKeyService.generateIfNotExists();
    } catch (e, st) {
      debugPrint('Identity key setup skipped during auth gate: $e');
      debugPrintStack(stackTrace: st);
    }

    // ============================
    // 4️⃣ LOAD USER DOCUMENT
    // ============================
    final snap = await _loadUserDoc(user.uid);

    if (eventToken != _authEventToken ||
        _isLoggingOut ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }

    // A Google login can create the Firebase account before a Firestore
    // profile exists. Derive onboarding from server state so a local flag race
    // (or an app restart) can never skip phone verification.
    final completed = snap.data()?['isProfileCompleted'] == true;
    final storedPhone = (snap.data()?['phonenumber'] ?? '').toString().trim();
    final isGoogleUser = user.providerData.any(
      (provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID,
    );
    final requiresGooglePhoneRepair = !completed || storedPhone.isEmpty;
    if (isGoogleUser && requiresGooglePhoneRepair) {
      final enrolledFactors = await user.multiFactor.getEnrolledFactors();
      final hasVerifiedPhone = enrolledFactors.any(
        (factor) => factor is PhoneMultiFactorInfo,
      );

      if (!hasVerifiedPhone) {
        Get.offAllNamed(AppRouter.enrollPhone);
        return;
      }
    }

    // ❌ CHƯA CÓ PROFILE → COMPLETE
    if (!snap.exists) {
      Get.offAllNamed(AppRouter.completeProfile);
      return;
    }

    // ============================
    // 5️⃣ ROUTE CUỐI CÙNG
    // ============================
    Get.offAllNamed(completed ? AppRouter.main : AppRouter.completeProfile);
    if (completed && Get.isRegistered<NotificationController>()) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!Get.isRegistered<NotificationController>()) return;
        Get.find<NotificationController>().flushPendingNavigation(
          allowMainRedirect: true,
        );
      });
    }
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

  Future<void> _holdSplashBeforeSignedOutRedirect(String redirectRoute) async {
    if (redirectRoute != AppRouter.welcome ||
        Get.currentRoute != AppRouter.splash) {
      return;
    }

    final shownAt = _logoutSplashShownAt;
    if (shownAt == null) {
      await Future.delayed(_minimumSplashDuration);
      return;
    }

    final elapsed = DateTime.now().difference(shownAt);
    final remaining = _minimumSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
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
  void beginLogout({String redirectRoute = AppRouter.welcome}) {
    _isLoggingOut = true;
    _signedOutRedirectRoute = redirectRoute;
    _logoutSplashShownAt = DateTime.now();
  }

  void reset() {
    _navigated = false;
    _isLoggingOut = false;
    _signedOutRedirectRoute = null;
    _logoutSplashShownAt = null;
  }

  Future<void> refreshCurrentUser() async {
    _navigated = false;
    await _handleAuth(FirebaseAuth.instance.currentUser);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
