import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';
import 'package:matchu_app/translations/auth_translations.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _googleSignInInitialized = false;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get db => _db;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized || kIsWeb) return;

    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }

  /* ======================= REGISTER ======================= */

  Future<void> registerWithEmailAndPassWord({
    required String email,
    required String password,
    required Function() onSuccess,
    required Function(String error) onFailed,
  }) async {
    try {
      // 1. Tạo tài khoản email/password
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception("Không tạo được user");

      // 2. Gửi mail verify
      await user.sendEmailVerification();

      // 3. Gọi callback thành công
      onSuccess();
    } on FirebaseAuthException catch (e) {
      onFailed(firebaseErrorToVietnamese(e.code));
    } catch (e) {
      onFailed(authTr("Đã xảy ra lỗi không xác định. Vui lòng thử lại."));
    }
  }

  /* ======================= ENROLL MFA SAU KHI EMAIL ĐÃ VERIFY ======================= */

  Future<void> sendEnrollMfaOtp({
    required String phonenumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User chưa đăng nhập");

      await user.reload();
      final refreshedUser = _auth.currentUser ?? user;
      if (!refreshedUser.emailVerified) {
        throw Exception(
          "Bạn phải xác minh email trước khi dùng số điện thoại.",
        );
      }

      final session = await refreshedUser.multiFactor.getSession();

      await _auth.verifyPhoneNumber(
        phoneNumber: phonenumber,
        multiFactorSession: session,
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          onFailed(firebaseErrorToVietnamese(e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
          // print("OTP ĐÃ ĐƯỢC GỬI - verificationId = $verificationId");
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onFailed(authTr("Không thể gửi OTP. Vui lòng thử lại."));
    }
  }

  Future<void> confirmRegisterOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User chưa đăng nhập");

      await user.reload();
      final refreshedUser = _auth.currentUser ?? user;
      if (!refreshedUser.emailVerified) {
        throw Exception("Email chưa được xác minh");
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

      await refreshedUser.multiFactor.enroll(assertion, displayName: "SMS");
      try {
        await refreshedUser.linkWithCredential(credential);
      } on FirebaseAuthException {
        // MFA enrollment remains the source of truth for the existing flow.
      }
    } on FirebaseAuthException catch (e) {
      throw firebaseErrorToVietnamese(e.code);
    } catch (e) {
      throw authTr("Đã xảy ra lỗi khi xác minh OTP.");
    }
  }

  /// Returns the number Firebase has actually verified as a phone MFA factor.
  /// A number typed in the UI must never be treated as verified account data.
  Future<String> getVerifiedPhoneNumber([User? user]) async {
    final currentUser = user ?? _auth.currentUser;
    if (currentUser == null) return '';

    final factors = await currentUser.multiFactor.getEnrolledFactors();
    for (final factor in factors) {
      if (factor is PhoneMultiFactorInfo) {
        return factor.phoneNumber.trim();
      }
    }

    return '';
  }

  Future<bool> isNicknameUnique(String nickname, {String? excludeUid}) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty) return false;

    final snap =
        await _db
            .collection('users')
            .where('nickname', isEqualTo: normalized)
            .limit(1)
            .get();

    if (snap.docs.isEmpty) {
      return true;
    }

    final currentUid = excludeUid ?? _auth.currentUser?.uid;
    return currentUid != null && snap.docs.first.id == currentUid;
  }

  Future<bool> isPhoneNumberUnique(
    String phoneNumber, {
    String? excludeUid,
  }) async {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) return false;

    final snap =
        await _db
            .collection('users')
            .where('phonenumber', isEqualTo: normalized)
            .limit(1)
            .get();

    if (snap.docs.isEmpty) {
      return true;
    }

    final currentUid = excludeUid ?? _auth.currentUser?.uid;
    return currentUid != null && snap.docs.first.id == currentUid;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      return _auth.signInWithPopup(provider);
    }

    await _ensureGoogleSignInInitialized();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> markGoogleProvider(UserCredential credential) async {
    final user = credential.user ?? _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    UserInfo? googleProvider;
    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') {
        googleProvider = provider;
        break;
      }
    }

    await userRef.set({
      'email': user.email,
      'googleId': googleProvider?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /* ======================= SAVE PROFILE ======================= */

  Future<void> saveUserProfile({
    required String fullname,
    required String nickname,
    DateTime? birthday,
    String? gender,
    List<String> interests = const [],
    String? avatarUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User chưa đăng nhập");

    // This remains correct even if the app restarts after OTP verification.
    final verifiedPhoneNumber = await getVerifiedPhoneNumber(user);
    if (verifiedPhoneNumber.isEmpty) {
      throw Exception(
        authTr("Vui lòng xác minh số điện thoại trước khi hoàn thiện hồ sơ."),
      );
    }

    await user.updateDisplayName(nickname);

    final userRef = _db.collection('users').doc(user.uid);
    final userSnap = await userRef.get();
    final isCreatingUserDoc = !userSnap.exists;
    UserInfo? googleProvider;
    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') {
        googleProvider = provider;
        break;
      }
    }

    final data = <String, dynamic>{
      "uid": user.uid,
      "email": user.email,
      "fullname": fullname,
      "nickname": nickname,
      "phonenumber": verifiedPhoneNumber,

      "googleId": googleProvider?.uid,

      "birthday": birthday?.toIso8601String(),
      "gender": gender,
      "bio": "",
      "interests": interests,

      "location": {"lat": null, "lng": null},

      "nearlyEnabled": true,
      "trustWarnings": 0,
      "totalReports": 0,

      "avgChatRating": 5.0,
      "totalChatRatings": 0,

      "followers": [],
      "following": [],
      "followingListVisibility": "everyone",
      "isPrivateAccount": false,

      "rank": 1,
      "experience": 0,
      "dailyExp": 0,
      "dailyMatchingCount": 0,
      "dailyMatchingDate": null,

      "totalPosts": 0,
      "totalLikes": 0,

      "activeStatus": "offline",
      "accountStatus": "active",

      "role": "user",
      "isProfileCompleted": false,
      "anonymousAvatar": null,

      "lastActiveAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    // Chỉ cấp các giá trị khởi tạo một lần khi tạo hồ sơ mới.
    if (isCreatingUserDoc) {
      data.addAll({
        "gem": UserModel.initialGemBalance,
        "reputationScore": 100,
        "reputationTodayDateKey": null,
        "reputationTodayClaimed": 0,
        "reputationTodayCap": 10,
        "reputationLastClaimAt": null,
        "isFaceVerified": false,
      });
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      data["avatarUrl"] = avatarUrl;
    }

    await userRef.set(data, SetOptions(merge: true));
  }

  /* ======================= LOGIN + MFA ======================= */

  Future<void> login({
    required String email,
    required String password,
    required Function() onSuccess,
    required Function(FirebaseAuthMultiFactorException e) onMfaRequired,
    required Function(String error) onFailed,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      await setOnlineStatus(true);
      onSuccess();
    } on FirebaseAuthMultiFactorException catch (e) {
      onMfaRequired(e);
    } on FirebaseAuthException catch (e) {
      onFailed(firebaseErrorToVietnamese(e.code));
    } catch (e) {
      onFailed(authTr("Lỗi không xác định."));
    }
  }

  Future<void> resolveMfaLogin({
    required FirebaseAuthMultiFactorException e,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    try {
      final resolver = e.resolver;
      PhoneMultiFactorInfo? phoneInfo;
      for (final hint in resolver.hints) {
        if (hint is PhoneMultiFactorInfo) {
          phoneInfo = hint;
          break;
        }
      }
      if (phoneInfo == null) {
        onFailed(authTr("Không tìm thấy số điện thoại xác minh MFA."));
        return;
      }

      await _auth.verifyPhoneNumber(
        multiFactorInfo: phoneInfo,
        multiFactorSession: resolver.session,
        verificationCompleted: (credential) async {
          final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
          await resolver.resolveSignIn(assertion);
          await setOnlineStatus(true);
        },
        verificationFailed: (FirebaseAuthException error) {
          onFailed(firebaseErrorToVietnamese(error.code));
        },
        codeSent: (verificationId, _) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onFailed(authTr("Không thể gửi OTP xác minh MFA."));
    }
  }

  Future<void> confirmLoginOtp({
    required FirebaseAuthMultiFactorException e,
    required String verificationId,
    required String smsCode,
  }) async {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final assertion = PhoneMultiFactorGenerator.getAssertion(cred);

    await e.resolver.resolveSignIn(assertion);
    await setOnlineStatus(true);
  }

  /* ======================= ONLINE / OFFLINE ======================= */

  Future<void> setOnlineStatus(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    await userRef.set({
      'activeStatus': online ? 'online' : 'offline',
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logout() async {
    await setOnlineStatus(false);
  }
}
