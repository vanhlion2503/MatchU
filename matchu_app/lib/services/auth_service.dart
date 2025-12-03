import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get db => _db;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /* ======================= REGISTER + MFA ======================= */

  Future<void> registerWithEmailAndPassWord({
    required String email,
    required String password,
    required String phonenumber,
    required Function(String verificationId) onCodeSent,
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

      // 2. Tạo session cho MFA
      final session = await user.multiFactor.getSession();

      // 3. Gửi OTP để enroll MFA với số điện thoại
      await _auth.verifyPhoneNumber(
        phoneNumber: phonenumber,
        multiFactorSession: session,

        verificationCompleted: (PhoneAuthCredential credential) async {
          // Ở bước đăng ký, ta KHÔNG auto verify, vì cần user nhập OTP tay
        },

        verificationFailed: (FirebaseAuthException e) {
          onFailed(e.message ?? "Gửi OTP bị lỗi");
        },

        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },

        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (e) {
      onFailed(e.toString());
    }
  }

  /// Xác nhận OTP đăng ký + enroll MFA SMS
  Future<void> confirmRegisterOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User chưa đăng nhập");

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final assertion =
          PhoneMultiFactorGenerator.getAssertion(credential);

      await user.multiFactor.enroll(assertion, displayName: "SMS");
    } catch (e) {
      rethrow;
    }
  }

  /* ======================= SAVE PROFILE ======================= */

  Future<void> saveUserProfile({
    required String fullname,
    required String nickname,
    required String phonenumber,
    DateTime? birthday,
    String? gender,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User chưa đăng nhập");

      await user.updateDisplayName(nickname);

      final docRef = _db.collection('users').doc(user.uid);

      await docRef.set({
        'uid': user.uid,
        'email': user.email,

        'fullname': fullname,
        'nickname': nickname,
        'phonenumber': phonenumber,

        'birthday': birthday?.toIso8601String(),
        'gender': gender,
        'bio': '',
        'avatarUrl': '',

        'location': {
          'lat': null,
          'lng': null,
        },

        'nearlyEnabled': true,
        'reputationScore': 100,
        'followersCount': 0,
        'followingCount': 0,
        'activeStatus': 'offline',

        // Các field thêm để dễ quản lý
        'emailVerified': user.emailVerified,
        'role': 'user',                 // ✅ phân quyền sau này
        'isProfileCompleted': false,    // ✅ ban đầu false, controller sẽ update true

        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(
        merge: true,
      ));
    } catch (e) {
      rethrow;
    }
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
      // Đăng nhập email/password
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await setOnlineStatus(true);

      onSuccess();
    } on FirebaseAuthMultiFactorException catch (e) {
      onMfaRequired(e);
    } on FirebaseAuthException catch (e) {
      onFailed(e.message ?? "Đăng nhập thất bại");
    } catch (e) {
      onFailed(e.toString());
    }
  }

  /// Gửi OTP khi login có MFA
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

        verificationCompleted:
            (PhoneAuthCredential credential) async {

          final assertion =
              PhoneMultiFactorGenerator.getAssertion(credential);
          await resolver.resolveSignIn(assertion);


          await setOnlineStatus(true);
        },

        verificationFailed: (FirebaseAuthException error) {
          onFailed(error.message ?? "OTP lỗi");
        },

        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },

        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onFailed(e.toString());
    }
  }

  /// Xác nhận OTP để hoàn tất đăng nhập MFA
  Future<void> confirmLoginOtp({
    required FirebaseAuthMultiFactorException e,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final assertion =
          PhoneMultiFactorGenerator.getAssertion(cred);

      await e.resolver.resolveSignIn(assertion);

      // ✅ Đăng nhập MFA thành công → set online
      await setOnlineStatus(true);
    } catch (e) {
      rethrow;
    }
  }

  /* ======================= ONLINE / OFFLINE ======================= */

  Future<void> setOnlineStatus(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update({
      'activeStatus': online ? 'online' : 'offline',
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /* ======================= LOGOUT ======================= */

  Future<void> logout() async {
    await setOnlineStatus(false);
    await _auth.signOut();
  }
}
