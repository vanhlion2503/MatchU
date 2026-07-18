import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/account_security/account_security_model.dart';

void main() {
  group('AccountSecurityInfo', () {
    test('detects providers and masks all but the last four phone digits', () {
      const info = AccountSecurityInfo(
        email: 'user@example.com',
        emailVerified: true,
        phoneNumber: '+84901234567',
        providerIds: {'password', 'google.com'},
        mfaEnabled: true,
      );

      expect(info.hasPasswordProvider, isTrue);
      expect(info.hasGoogleProvider, isTrue);
      expect(info.maskedPhoneNumber, '********4567');
      expect(info.providerLabels, ['Email và mật khẩu', 'Google']);
    });

    test('does not fail when a legacy phone number is short', () {
      const info = AccountSecurityInfo(
        email: '',
        emailVerified: false,
        phoneNumber: '1234',
        providerIds: {},
        mfaEnabled: false,
      );

      expect(info.maskedPhoneNumber, '1234');
      expect(info.providerLabels, isEmpty);
    });
  });

  group('AccountDeviceModel', () {
    test('parses Firestore timestamps and marks the current device', () {
      final lastActiveAt = DateTime.utc(2026, 7, 18, 12, 30);
      final device = AccountDeviceModel.fromFirestore(
        id: 'device-1234567890',
        currentDeviceId: 'device-1234567890',
        data: {
          'platform': 'android',
          'e2eeStatus': 'active',
          'lastActiveAt': Timestamp.fromDate(lastActiveAt),
        },
      );

      expect(device.isCurrent, isTrue);
      expect(device.isActive, isTrue);
      expect(
        device.lastActiveAt?.millisecondsSinceEpoch,
        lastActiveAt.millisecondsSinceEpoch,
      );
      expect(device.shortId, 'device-1');
      expect(device.displayName, 'Thiết bị Android (thiết bị này)');
    });

    test('uses safe defaults for legacy device documents', () {
      final device = AccountDeviceModel.fromFirestore(
        id: 'legacy',
        currentDeviceId: 'current',
        data: const {},
      );

      expect(device.platform, 'unknown');
      expect(device.status, 'active');
      expect(device.isCurrent, isFalse);
    });
  });
}
