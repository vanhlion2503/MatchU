import 'package:cloud_firestore/cloud_firestore.dart';

class AccountSuspensionNotice {
  const AccountSuspensionNotice({
    required this.reason,
    required this.expiresAt,
  });

  final String reason;
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) {
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(now);
  }

  String get displayReason {
    final normalized = reason.trim();
    return normalized.isEmpty
        ? 'Tài khoản vi phạm quy định sử dụng của MatchU.'
        : normalized;
  }

  String get expiryMessage {
    final expiry = expiresAt?.toLocal();
    if (expiry == null) return 'Thời hạn tạm khóa: Không thời hạn';
    return 'Tạm khóa đến ${formatDateTime(expiry)}';
  }

  static AccountSuspensionNotice? fromUserData(Map<String, dynamic>? userData) {
    if (userData == null ||
        (userData['accountStatus'] ?? '').toString().trim().toLowerCase() !=
            'suspended') {
      return null;
    }

    final rawSuspension = userData['suspension'];
    final suspension =
        rawSuspension is Map
            ? Map<String, dynamic>.from(rawSuspension)
            : const <String, dynamic>{};
    return AccountSuspensionNotice(
      reason: (suspension['reason'] ?? '').toString().trim(),
      expiresAt: _parseDate(suspension['expiresAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.hour)}:${twoDigits(value.minute)}, '
        '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}';
  }
}
