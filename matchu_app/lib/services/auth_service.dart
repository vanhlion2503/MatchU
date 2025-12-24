import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get db => _db;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
      onFailed("Đã xảy ra lỗi không xác định. Vui lòng thử lại.");
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
      if (!user.emailVerified) {
        throw Exception("Bạn phải xác minh email trước khi dùng số điện thoại.");
      }

      final session = await user.multiFactor.getSession();

      await _auth.verifyPhoneNumber(
        phoneNumber: phonenumber,
        multiFactorSession: session,
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          onFailed(e.message ?? "Gửi OTP bị lỗi");
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
          // print("OTP ĐÃ ĐƯỢC GỬI - verificationId = $verificationId");
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onFailed("Không thể gửi OTP. Vui lòng thử lại.");
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
      if (!user.emailVerified) {
        throw Exception("Email chưa được xác minh");
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final assertion =
          PhoneMultiFactorGenerator.getAssertion(credential);

      await user.multiFactor.enroll(assertion, displayName: "SMS");
    } on FirebaseAuthException catch (e) {
      throw firebaseErrorToVietnamese(e.code);
    } catch (e) {
      throw "Đã xảy ra lỗi khi xác minh OTP.";
    }
  }

  /* ======================= SAVE PROFILE ======================= */

  Future<void> saveUserProfile({
    required String fullname,
    required String nickname,
    required String phonenumber,
    DateTime? birthday,
    String? gender,
    String? avatarUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User chưa đăng nhập");

    await user.updateDisplayName(nickname);

    final data = <String, dynamic>{
      "uid": user.uid,
      "email": user.email,
      "fullname": fullname,
      "nickname": nickname,
      "phonenumber": phonenumber,

      "googleId": null,

      "birthday": birthday?.toIso8601String(),
      "gender": gender,
      "bio": "",
      "interests": [],

      "location": {
        "lat": null,
        "lng": null,
      },

      "nearlyEnabled": true,
      "reputationScore": 100,
      "trustWarnings": 0,
      "totalReports": 0,

      "avgChatRating": 5.0,
      "totalChatRatings": 0,

      "followers": [],
      "following": [],

      "rank": 1,
      "experience": 0,
      "dailyExp": 0,

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

    // ⭐⭐⭐ CHỈ GHI KHI CÓ AVATAR
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      data["avatarUrl"] = avatarUrl;
    }

    await _db
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
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
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await setOnlineStatus(true);
      onSuccess();
    } on FirebaseAuthMultiFactorException catch (e) {
      onMfaRequired(e);
    } on FirebaseAuthException catch (e) {
      onFailed(firebaseErrorToVietnamese(e.code));
    } catch (e) {
      onFailed("Lỗi không xác định.");
    }
  }

  Future<void> resolveMfaLogin({
    required FirebaseAuthMultiFactorException e,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    try {
      final resolver = e.resolver;
      final phoneInfo = resolver.hints.first as PhoneMultiFactorInfo;

      await _auth.verifyPhoneNumber(
        multiFactorInfo: phoneInfo,
        multiFactorSession: resolver.session,
        verificationCompleted: (credential) async {
          final assertion =
              PhoneMultiFactorGenerator.getAssertion(credential);
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
      onFailed("Không thể gửi OTP xác minh MFA.");
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

    final assertion =
        PhoneMultiFactorGenerator.getAssertion(cred);

    await e.resolver.resolveSignIn(assertion);
    await setOnlineStatus(true);
  }

  /* ======================= ONLINE / OFFLINE ======================= */

  Future<void> setOnlineStatus(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'activeStatus': online ? 'online' : 'offline',
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logout() async {
    await setOnlineStatus(false);
    await _auth.signOut();
  }
}
