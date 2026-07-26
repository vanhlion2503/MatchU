import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountFeature {
  posts('posts', 'đăng bài'),
  comments('comments', 'bình luận'),
  chat('chat', 'gửi tin nhắn'),
  matching('matching', 'sử dụng matching'),
  calls('calls', 'thực hiện cuộc gọi');

  const AccountFeature(this.firestoreValue, this.actionLabel);

  final String firestoreValue;
  final String actionLabel;
}

class AccountRestriction {
  const AccountRestriction({
    required this.features,
    this.reason = '',
    this.reportId = '',
    this.appliedBy = '',
    this.appliedAt,
    this.expiresAt,
  });

  final Set<AccountFeature> features;
  final String reason;
  final String reportId;
  final String appliedBy;
  final DateTime? appliedAt;
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) {
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(now);
  }

  bool blocks(AccountFeature feature, {required DateTime now}) {
    return isActiveAt(now) && features.contains(feature);
  }

  factory AccountRestriction.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AccountRestriction(features: <AccountFeature>{});
    }
    final rawFeatures = json['features'];
    final values =
        rawFeatures is Iterable
            ? rawFeatures.map((value) => value.toString().trim()).toSet()
            : const <String>{};
    return AccountRestriction(
      features:
          AccountFeature.values
              .where((feature) => values.contains(feature.firestoreValue))
              .toSet(),
      reason: (json['reason'] ?? '').toString().trim(),
      reportId: (json['reportId'] ?? '').toString().trim(),
      appliedBy: (json['appliedBy'] ?? '').toString().trim(),
      appliedAt: _parseDate(json['appliedAt']),
      expiresAt: _parseDate(json['expiresAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class AccountAccessDecision {
  const AccountAccessDecision.allowed()
    : allowed = true,
      code = null,
      message = null,
      expiresAt = null;

  const AccountAccessDecision.denied({
    required this.code,
    required this.message,
    this.expiresAt,
  }) : allowed = false;

  final bool allowed;
  final String? code;
  final String? message;
  final DateTime? expiresAt;
}

class AccountAccessException implements Exception {
  const AccountAccessException({
    required this.code,
    required this.message,
    required this.feature,
    this.expiresAt,
  });

  final String code;
  final String message;
  final AccountFeature feature;
  final DateTime? expiresAt;

  @override
  String toString() => message;
}

class AccountAccessPolicy {
  const AccountAccessPolicy._();

  static AccountAccessDecision evaluate({
    required String accountStatus,
    required AccountRestriction? restriction,
    required AccountFeature feature,
    required DateTime now,
  }) {
    final status = accountStatus.trim().toLowerCase();
    switch (status) {
      case '':
      case 'active':
        return const AccountAccessDecision.allowed();
      case 'deleting':
      case 'deleted':
        return const AccountAccessDecision.denied(
          code: 'account-unavailable',
          message: 'Tài khoản này không còn hoạt động.',
        );
      case 'suspended':
        if (restriction != null && !restriction.isActiveAt(now)) {
          return const AccountAccessDecision.allowed();
        }
        return AccountAccessDecision.denied(
          code: 'account-suspended',
          message: _statusMessage('Tài khoản đang bị tạm khóa', restriction),
          expiresAt: restriction?.expiresAt,
        );
      case 'banned':
        return AccountAccessDecision.denied(
          code: 'account-banned',
          message: _statusMessage('Tài khoản đã bị cấm', restriction),
          expiresAt: restriction?.expiresAt,
        );
      case 'restricted':
        final currentRestriction = restriction;
        if (currentRestriction == null) {
          return const AccountAccessDecision.denied(
            code: 'account-restricted',
            message: 'Tài khoản đang bị hạn chế. Vui lòng liên hệ hỗ trợ.',
          );
        }
        if (!currentRestriction.isActiveAt(now)) {
          return const AccountAccessDecision.allowed();
        }
        if (!currentRestriction.features.contains(feature)) {
          return const AccountAccessDecision.allowed();
        }
        return AccountAccessDecision.denied(
          code: 'feature-restricted',
          message: _featureMessage(feature, currentRestriction),
          expiresAt: currentRestriction.expiresAt,
        );
      default:
        return const AccountAccessDecision.denied(
          code: 'account-status-invalid',
          message:
              'Trạng thái tài khoản không hợp lệ. Vui lòng liên hệ hỗ trợ.',
        );
    }
  }

  static String _featureMessage(
    AccountFeature feature,
    AccountRestriction restriction,
  ) {
    final reason = restriction.reason.trim();
    final expiry = restriction.expiresAt;
    final parts = <String>[
      'Tài khoản đang bị hạn chế ${feature.actionLabel}.',
      if (reason.isNotEmpty) 'Lý do: $reason.',
      if (expiry != null) 'Thời hạn: ${_formatDate(expiry)}.',
    ];
    return parts.join(' ');
  }

  static String _statusMessage(String prefix, AccountRestriction? restriction) {
    final reason = restriction?.reason.trim() ?? '';
    final expiry = restriction?.expiresAt;
    return <String>[
      '$prefix.',
      if (reason.isNotEmpty) 'Lý do: $reason.',
      if (expiry != null) 'Thời hạn: ${_formatDate(expiry)}.',
    ].join(' ');
  }

  static String _formatDate(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
