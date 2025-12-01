import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get db => _db;

  /* ======================= REGISTER ======================= */

  Future<void> registerWithEmailAndPassWord({
    required String email,
    required String password,
    required String phonenumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw Exception("Không tạo được user");
      }

      final session = await user.multiFactor.getSession();

      await _auth.verifyPhoneNumber(
        phoneNumber: phonenumber,
        multiFactorSession: session,

        verificationCompleted: (PhoneAuthCredential credential) async {},

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

  /* ======================= CONFIRM REGISTER OTP ======================= */

  Future<void> confirmRegisterOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User chưa đăng nhập");
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final assertion =
          PhoneMultiFactorGenerator.getAssertion(credential);

      await user.multiFactor.enroll(
        assertion,
        displayName: "SMS",
      );
    } catch (e) {
      rethrow;
    }
  }

  /* ======================= SAVE USER PROFILE ======================= */

  Future<void> saveUserProfile({
    required String fullname,
    required String nickname,
    required String phonenumber,
    DateTime? birthday,
    String? gender,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User chưa đăng nhập");
      }

      await user.updateDisplayName(nickname);

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
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

        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /* ======================= LOGIN ======================= */

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
      onSuccess();
    } on FirebaseAuthMultiFactorException catch (e) {
      onMfaRequired(e);
    } on FirebaseAuthException catch (e) {
      onFailed(e.message ?? "Đăng nhập thất bại");
    } catch (e) {
      onFailed(e.toString());
    }
  }

  /* ======================= SEND MFA OTP LOGIN ======================= */

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

  /* ======================= CONFIRM MFA LOGIN OTP ======================= */

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
    } catch (e) {
      rethrow;
    }
  }

  /* ======================= STATUS ======================= */

  Future<void> setOnlineStatus(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update({
      'activeStatus': online ? 'online' : 'offline',
    });
  }

  /* ======================= LOGOUT ======================= */

  Future<void> logout() async {
    await setOnlineStatus(false);
    await _auth.signOut();
  }
}
