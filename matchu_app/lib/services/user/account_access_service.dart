import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/account_access/account_access_model.dart';

/// Reads the latest server-managed account state before a restricted action.
///
/// The mobile application never writes these fields. Firestore Rules and Cloud
/// Functions remain the authoritative enforcement layer.
class AccountAccessService {
  AccountAccessService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DateTime Function()? clock,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  Future<AccountAccessDecision> check(AccountFeature feature) async {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      return const AccountAccessDecision.denied(
        code: 'unauthenticated',
        message: 'Vui lòng đăng nhập để tiếp tục.',
      );
    }

    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return const AccountAccessDecision.denied(
        code: 'account-unavailable',
        message: 'Không tìm thấy hồ sơ tài khoản. Vui lòng liên hệ hỗ trợ.',
      );
    }

    return AccountAccessPolicy.evaluate(
      accountStatus: (data['accountStatus'] ?? 'active').toString(),
      restriction:
          data['restriction'] is Map
              ? AccountRestriction.fromJson(
                Map<String, dynamic>.from(data['restriction'] as Map),
              )
              : null,
      feature: feature,
      now: _clock(),
    );
  }

  Future<void> ensureAllowed(AccountFeature feature) async {
    final decision = await check(feature);
    if (decision.allowed) return;

    throw AccountAccessException(
      code: decision.code ?? 'account-access-denied',
      message:
          decision.message ?? 'Tài khoản không thể thực hiện thao tác này.',
      feature: feature,
      expiresAt: decision.expiresAt,
    );
  }
}
