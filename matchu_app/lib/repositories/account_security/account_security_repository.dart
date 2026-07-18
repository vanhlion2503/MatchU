import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:matchu_app/models/account_security/account_security_model.dart';
import 'package:matchu_app/services/security/device_service.dart';

class MfaReauthenticationChallenge {
  const MfaReauthenticationChallenge({
    required this.resolver,
    required this.verificationId,
    required this.maskedPhoneNumber,
  });

  final MultiFactorResolver resolver;
  final String verificationId;
  final String maskedPhoneNumber;
}

class PhoneChangeChallenge {
  const PhoneChangeChallenge({
    required this.verificationId,
    required this.phoneNumber,
    this.credential,
  });

  final String verificationId;
  final String phoneNumber;
  final PhoneAuthCredential? credential;
}

class AccountSecurityRepository {
  AccountSecurityRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  User get _currentUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Phiên đăng nhập không còn hiệu lực.');
    }
    return user;
  }

  Future<AccountSecurityInfo> loadAccountInfo() async {
    await _currentUser.reload();
    final user = _currentUser;
    final factors = await user.multiFactor.getEnrolledFactors();
    final phoneFactors =
        factors.whereType<PhoneMultiFactorInfo>().toList()..sort(
          (a, b) => b.enrollmentTimestamp.compareTo(a.enrollmentTimestamp),
        );

    final profileSnap =
        await _firestore.collection('users').doc(user.uid).get();
    final profile = profileSnap.data() ?? const <String, dynamic>{};
    final email = (user.email ?? profile['email'] ?? '').toString().trim();
    final phoneNumber =
        phoneFactors.isNotEmpty
            ? phoneFactors.first.phoneNumber.trim()
            : (user.phoneNumber ?? profile['phonenumber'] ?? '')
                .toString()
                .trim();

    // Firebase Auth is the source of truth. This also repairs older profiles
    // after an email verification link or MFA phone change was completed.
    await _syncProfileAuthFields(
      userId: user.uid,
      profile: profile,
      email: email,
      phoneNumber: phoneNumber,
    );

    return AccountSecurityInfo(
      email: email,
      emailVerified: user.emailVerified,
      phoneNumber: phoneNumber,
      providerIds:
          user.providerData
              .map((provider) => provider.providerId.trim())
              .where((providerId) => providerId.isNotEmpty)
              .toSet(),
      mfaEnabled: factors.isNotEmpty,
    );
  }

  Future<void> _syncProfileAuthFields({
    required String userId,
    required Map<String, dynamic> profile,
    required String email,
    required String phoneNumber,
  }) async {
    final update = <String, dynamic>{};
    if (email.isNotEmpty && profile['email'] != email) {
      update['email'] = email;
    }
    if (phoneNumber.isNotEmpty && profile['phonenumber'] != phoneNumber) {
      update['phonenumber'] = phoneNumber;
    }
    if (update.isEmpty) return;

    update['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('users')
        .doc(userId)
        .set(update, SetOptions(merge: true));
  }

  Future<String> currentDeviceId() => DeviceService.getDeviceId();

  Stream<List<AccountDeviceModel>> watchDevices({
    required String currentDeviceId,
  }) {
    final userId = _currentUser.uid;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .snapshots()
        .map((snapshot) {
          final devices =
              snapshot.docs
                  .map(
                    (doc) => AccountDeviceModel.fromFirestore(
                      id: doc.id,
                      data: doc.data(),
                      currentDeviceId: currentDeviceId,
                    ),
                  )
                  .toList();
          devices.sort((a, b) {
            if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
            final aTime =
                a.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return devices;
        });
  }

  Future<MfaReauthenticationChallenge?> reauthenticate({
    String? currentPassword,
  }) async {
    final user = _currentUser;
    try {
      if (currentPassword != null && currentPassword.isNotEmpty) {
        final email = user.email?.trim() ?? '';
        if (email.isEmpty) {
          throw StateError('Tài khoản không có email để xác thực lại.');
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        final provider =
            GoogleAuthProvider()
              ..addScope('email')
              ..addScope('profile');
        if (kIsWeb) {
          await user.reauthenticateWithPopup(provider);
        } else {
          await user.reauthenticateWithProvider(provider);
        }
      }
      await user.getIdToken(true);
      return null;
    } on FirebaseAuthMultiFactorException catch (error) {
      return _startMfaReauthentication(error);
    }
  }

  Future<MfaReauthenticationChallenge> _startMfaReauthentication(
    FirebaseAuthMultiFactorException error,
  ) async {
    final phoneInfo =
        error.resolver.hints.whereType<PhoneMultiFactorInfo>().firstOrNull;
    if (phoneInfo == null) {
      throw StateError('Không tìm thấy số điện thoại MFA để xác thực.');
    }

    final completer = Completer<MfaReauthenticationChallenge>();
    await _auth.verifyPhoneNumber(
      multiFactorInfo: phoneInfo,
      multiFactorSession: error.resolver.session,
      verificationCompleted: (credential) async {
        if (completer.isCompleted) return;
        try {
          final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
          await error.resolver.resolveSignIn(assertion);
          await _currentUser.getIdToken(true);
          // Auto verification does not need a visible OTP dialog.
          completer.complete(
            MfaReauthenticationChallenge(
              resolver: error.resolver,
              verificationId: '',
              maskedPhoneNumber: phoneInfo.phoneNumber,
            ),
          );
        } catch (exception, stackTrace) {
          completer.completeError(exception, stackTrace);
        }
      },
      verificationFailed: (exception) {
        if (!completer.isCompleted) completer.completeError(exception);
      },
      codeSent: (verificationId, _) {
        if (completer.isCompleted) return;
        completer.complete(
          MfaReauthenticationChallenge(
            resolver: error.resolver,
            verificationId: verificationId,
            maskedPhoneNumber: phoneInfo.phoneNumber,
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future.timeout(const Duration(minutes: 2));
  }

  Future<void> completeMfaReauthentication({
    required MfaReauthenticationChallenge challenge,
    required String smsCode,
  }) async {
    if (challenge.verificationId.isEmpty) return;
    final credential = PhoneAuthProvider.credential(
      verificationId: challenge.verificationId,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    await challenge.resolver.resolveSignIn(assertion);
    await _currentUser.getIdToken(true);
  }

  Future<void> requestEmailChange(String newEmail) async {
    await _currentUser.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    await _currentUser.updatePassword(newPassword);
    await _currentUser.getIdToken(true);
  }

  Future<PhoneChangeChallenge> startPhoneChange(String phoneNumber) async {
    final normalizedPhone = phoneNumber.trim();
    final duplicate =
        await _firestore
            .collection('users')
            .where('phonenumber', isEqualTo: normalizedPhone)
            .limit(1)
            .get();
    if (duplicate.docs.any((doc) => doc.id != _currentUser.uid)) {
      throw StateError('Số điện thoại này đã được sử dụng.');
    }

    final session = await _currentUser.multiFactor.getSession();
    final completer = Completer<PhoneChangeChallenge>();
    await _auth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      multiFactorSession: session,
      verificationCompleted: (credential) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneChangeChallenge(
              verificationId: '',
              phoneNumber: normalizedPhone,
              credential: credential,
            ),
          );
        }
      },
      verificationFailed: (exception) {
        if (!completer.isCompleted) completer.completeError(exception);
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneChangeChallenge(
              verificationId: verificationId,
              phoneNumber: normalizedPhone,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future.timeout(const Duration(minutes: 2));
  }

  Future<void> completePhoneChange({
    required PhoneChangeChallenge challenge,
    required String smsCode,
  }) async {
    final user = _currentUser;
    final previousFactors = await user.multiFactor.getEnrolledFactors();
    final previousFactorIds =
        previousFactors.map((factor) => factor.uid).toSet();
    final credential =
        challenge.credential ??
        PhoneAuthProvider.credential(
          verificationId: challenge.verificationId,
          smsCode: smsCode,
        );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    // Enroll first so the account never has a gap without its required MFA.
    await user.multiFactor.enroll(assertion, displayName: 'SMS');
    final updatedFactors = await user.multiFactor.getEnrolledFactors();
    final newFactor =
        updatedFactors
            .whereType<PhoneMultiFactorInfo>()
            .where((factor) => !previousFactorIds.contains(factor.uid))
            .firstOrNull;

    try {
      await user.updatePhoneNumber(credential);
    } on FirebaseAuthException {
      // The MFA enrollment is the source of truth; some Firebase platforms do
      // not allow reusing the same SMS credential for the phone provider.
    }

    await _firestore.collection('users').doc(user.uid).set({
      'phonenumber': challenge.phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (newFactor != null) {
      for (final factor in previousFactors.whereType<PhoneMultiFactorInfo>()) {
        await user.multiFactor.unenroll(factorUid: factor.uid);
      }
    }
    await user.reload();
    await _currentUser.getIdToken(true);
  }

  Future<void> revokeAllSessions() async {
    await _currentUser.getIdToken(true);
    await _functions
        .httpsCallable('revokeAccountSessions')
        .call<Map<Object?, Object?>>();
  }

  Future<void> deleteAccount() async {
    await _currentUser.getIdToken(true);
    await _functions
        .httpsCallable('deleteAccount')
        .call<Map<Object?, Object?>>();
  }
}
