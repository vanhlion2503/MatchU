String maskOtpPhoneNumber(String phone) {
  final value = phone.trim().replaceAll(RegExp(r'\s+'), '');
  if (value.isEmpty) return value;

  // Firebase MFA can return an already-masked hint such as +*******6789.
  // The hidden digits cannot be recovered on the client, so keep it stable.
  if (value.contains('*')) return value;

  final hasPlus = value.startsWith('+');
  final digits = (hasPlus ? value.substring(1) : value).replaceAll(
    RegExp(r'\D'),
    '',
  );

  const visibleStart = 2;
  const visibleEnd = 4;
  if (digits.length <= visibleStart + visibleEnd) return value;

  final start = digits.substring(0, visibleStart);
  final end = digits.substring(digits.length - visibleEnd);
  final prefix = hasPlus ? '+$start' : start;

  return '$prefix****$end';
}
