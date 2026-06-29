import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

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
      // 1. Táº¡o tÃ i khoáº£n email/password
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception("KhÃ´ng táº¡o Ä‘Æ°á»£c user");

      // 2. Gá»­i mail verify
      await user.sendEmailVerification();

      // 3. Gá»i callback thÃ nh cÃ´ng
      onSuccess();
    } on FirebaseAuthException catch (e) {
      onFailed(firebaseErrorToVietnamese(e.code));
    } catch (e) {
      onFailed(
        "ÄÃ£ xáº£y ra lá»—i khÃ´ng xÃ¡c Ä‘á»‹nh. Vui lÃ²ng thá»­ láº¡i.",
      );
    }
  }

  /* ======================= ENROLL MFA SAU KHI EMAIL ÄÃƒ VERIFY ======================= */

  Future<void> sendEnrollMfaOtp({
    required String phonenumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User chÆ°a Ä‘Äƒng nháº­p");

      await user.reload();
      final refreshedUser = _auth.currentUser ?? user;
      if (!refreshedUser.emailVerified) {
        throw Exception(
          "Báº¡n pháº£i xÃ¡c minh email trÆ°á»›c khi dÃ¹ng sá»‘ Ä‘iá»‡n thoáº¡i.",
        );
      }

      final session = await refreshedUser.multiFactor.getSession();

      await _auth.verifyPhoneNumber(
        phoneNumber: phonenumber,
        multiFactorSession: session,
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          onFailed(e.message ?? "Gá»­i OTP bá»‹ lá»—i");
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
          // print("OTP ÄÃƒ ÄÆ¯á»¢C Gá»¬I - verificationId = $verificationId");
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onFailed("KhÃ´ng thá»ƒ gá»­i OTP. Vui lÃ²ng thá»­ láº¡i.");
    }
  }

  Future<void> confirmRegisterOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User chÆ°a Ä‘Äƒng nháº­p");

      await user.reload();
      final refreshedUser = _auth.currentUser ?? user;
      if (!refreshedUser.emailVerified) {
        throw Exception("Email chÆ°a Ä‘Æ°á»£c xÃ¡c minh");
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
      throw "ÄÃ£ xáº£y ra lá»—i khi xÃ¡c minh OTP.";
    }
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
    required String phonenumber,
    DateTime? birthday,
    String? gender,
    String? avatarUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User chÆ°a Ä‘Äƒng nháº­p");

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
      "phonenumber": phonenumber,

      "googleId": googleProvider?.uid,

      "birthday": birthday?.toIso8601String(),
      "gender": gender,
      "bio": "",
      "interests": [],

      "location": {"lat": null, "lng": null},

      "nearlyEnabled": true,
      "trustWarnings": 0,
      "totalReports": 0,

      "avgChatRating": 5.0,
      "totalChatRatings": 0,

      "followers": [],
      "following": [],

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

    // â­â­â­ CHá»ˆ GHI KHI CÃ“ AVATAR
    if (isCreatingUserDoc) {
      data.addAll({
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
      onFailed("Lá»—i khÃ´ng xÃ¡c Ä‘á»‹nh.");
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
        onFailed("KhÃ´ng tÃ¬m tháº¥y sá»‘ Ä‘iá»‡n thoáº¡i xÃ¡c minh MFA.");
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
      onFailed("KhÃ´ng thá»ƒ gá»­i OTP xÃ¡c minh MFA.");
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
