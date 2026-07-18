import 'package:cloud_firestore/cloud_firestore.dart';

class AccountSecurityInfo {
  const AccountSecurityInfo({
    required this.email,
    required this.emailVerified,
    required this.phoneNumber,
    required this.providerIds,
    required this.mfaEnabled,
  });

  final String email;
  final bool emailVerified;
  final String phoneNumber;
  final Set<String> providerIds;
  final bool mfaEnabled;

  bool get hasPasswordProvider => providerIds.contains('password');
  bool get hasGoogleProvider => providerIds.contains('google.com');

  String get maskedPhoneNumber {
    final value = phoneNumber.trim();
    if (value.length <= 4) return value;
    return '${'*' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  List<String> get providerLabels {
    final labels = <String>[];
    if (hasPasswordProvider) labels.add('Email và mật khẩu');
    if (hasGoogleProvider) labels.add('Google');
    if (providerIds.contains('phone')) labels.add('Số điện thoại');
    return labels;
  }
}

class AccountDeviceModel {
  const AccountDeviceModel({
    required this.id,
    required this.platform,
    required this.status,
    required this.isCurrent,
    this.createdAt,
    this.lastActiveAt,
  });

  final String id;
  final String platform;
  final String status;
  final bool isCurrent;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  bool get isActive => status == 'active';

  String get displayName {
    final platformName = switch (platform.toLowerCase()) {
      'android' => 'Thiết bị Android',
      'ios' => 'iPhone hoặc iPad',
      'web' => 'Trình duyệt web',
      'windows' => 'Máy tính Windows',
      'macos' => 'Máy Mac',
      'linux' => 'Máy tính Linux',
      _ => 'Thiết bị không xác định',
    };
    return isCurrent ? '$platformName (thiết bị này)' : platformName;
  }

  String get shortId => id.length <= 8 ? id : id.substring(0, 8);

  factory AccountDeviceModel.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
    required String currentDeviceId,
  }) {
    DateTime? readDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return AccountDeviceModel(
      id: id,
      platform: (data['platform'] ?? 'unknown').toString().trim(),
      status: (data['e2eeStatus'] ?? 'active').toString().trim(),
      isCurrent: id == currentDeviceId,
      createdAt: readDate(data['createdAt']),
      lastActiveAt: readDate(data['lastActiveAt']),
    );
  }
}
