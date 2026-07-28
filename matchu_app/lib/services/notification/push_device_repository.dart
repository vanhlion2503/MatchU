import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:matchu_app/services/security/device_service.dart';

/// Stores push credentials separately from the public E2EE device directory.
///
/// Documents under `notificationDevices` are owner-only in Firestore Rules,
/// while Cloud Functions can still read them through the Admin SDK.
class PushDeviceRepository {
  PushDeviceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> upsert({
    required String userId,
    required String platform,
    required NotificationSettings settings,
    required String appVersion,
    required String buildNumber,
    required String locale,
    String? token,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final deviceRef = _notificationDeviceRef(userId, deviceId);
    final isAuthorized = _isAuthorized(settings.authorizationStatus);

    await deviceRef.set({
      'platform': platform,
      'appVersion': appVersion.trim(),
      'buildNumber': buildNumber.trim(),
      'locale': locale.trim(),
      'status': 'active',
      'pushEnabled': isAuthorized,
      'notificationPermission': _statusName(settings.authorizationStatus),
      'notificationUpdatedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      if (token != null && token.trim().isNotEmpty) ...{
        'fcmToken': token.trim(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    // Remove credentials written by older app versions. This is best-effort so
    // a missing legacy device document never prevents notification setup.
    await _removeLegacyPushFields(userId, deviceId);
  }

  Future<void> markInactive(String userId) async {
    final deviceId = await DeviceService.getDeviceId();
    try {
      await _notificationDeviceRef(userId, deviceId).update({
        'status': 'inactive',
        'pushEnabled': false,
        'notificationPermission': 'denied',
        'notificationUpdatedAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    }

    await _removeLegacyPushFields(userId, deviceId);
  }

  DocumentReference<Map<String, dynamic>> _notificationDeviceRef(
    String userId,
    String deviceId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notificationDevices')
        .doc(deviceId);
  }

  Future<void> _removeLegacyPushFields(String userId, String deviceId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .update({
            'fcmToken': FieldValue.delete(),
            'fcmTokenUpdatedAt': FieldValue.delete(),
            'pushEnabled': FieldValue.delete(),
            'notificationPermission': FieldValue.delete(),
            'notificationUpdatedAt': FieldValue.delete(),
            'lastNotificationOpenedAt': FieldValue.delete(),
          });
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    }
  }

  static bool _isAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  static String _statusName(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'authorized';
      case AuthorizationStatus.denied:
        return 'denied';
      case AuthorizationStatus.provisional:
        return 'provisional';
      case AuthorizationStatus.notDetermined:
        return 'not_determined';
    }
  }
}
