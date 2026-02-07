import 'package:flutter/services.dart';

class ProfileInputValidator {
  static const int minFullnameLength = 4;
  static const int maxFullnameLength = 50;
  static const int minNicknameLength = 2;
  static const int maxNicknameLength = 20;

  static final RegExp _fullnameAllowed = RegExp(
    r'^[\p{Script=Latin}\p{M} ]+$',
    unicode: true,
  );
  static final RegExp _nicknameAllowed = RegExp(
    r'^[\p{Script=Latin}\p{M}0-9._]+$',
    unicode: true,
  );
  static final RegExp _containsMultiSpaces = RegExp(r' {2,}');
  static final RegExp _startsOrEndsWithDotOrUnderscore = RegExp(r'^[_.]|[_.]$');
  static final RegExp _containsLink = RegExp(
    r'(https?:\/\/|www\.|[a-z0-9-]+\.(com|net|org|vn|io|me|co|info|biz)\b)',
    caseSensitive: false,
  );
  static final RegExp _fullnameTypingAllowed = RegExp(
    r'[\p{Script=Latin}\p{M} ]',
    unicode: true,
  );
  static final RegExp _nicknameTypingAllowed = RegExp(
    r'[\p{Script=Latin}\p{M}0-9._]',
    unicode: true,
  );

  static final List<TextInputFormatter> fullnameInputFormatters = [
    FilteringTextInputFormatter.allow(_fullnameTypingAllowed),
  ];

  static final List<TextInputFormatter> nicknameInputFormatters = [
    FilteringTextInputFormatter.allow(_nicknameTypingAllowed),
  ];

  static String normalizeFullname(String input) => input.trim();
  static String normalizeNickname(String input) => input.trim();

  static String? validateFullname(String input) {
    final value = normalizeFullname(input);

    if (value.isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    if (value.length < minFullnameLength || value.length > maxFullnameLength) {
      return 'Họ và tên phải từ $minFullnameLength đến $maxFullnameLength ký tự';
    }
    if (_containsMultiSpaces.hasMatch(value)) {
      return 'Họ và tên không được có nhiều khoảng trắng liên tiếp';
    }
    if (_containsLink.hasMatch(value)) {
      return 'Họ và tên không được chứa link hoặc username';
    }
    if (!_fullnameAllowed.hasMatch(value)) {
      return 'Họ và tên chỉ gồm chữ cái tiếng Việt và khoảng trắng';
    }

    return null;
  }

  static String? validateNickname(String input) {
    final value = normalizeNickname(input);

    if (value.isEmpty) {
      return 'Vui lòng nhập biệt danh';
    }
    if (value.length < minNicknameLength || value.length > maxNicknameLength) {
      return 'Biệt danh phải từ $minNicknameLength đến $maxNicknameLength ký tự';
    }
    if (!_nicknameAllowed.hasMatch(value)) {
      return 'Biệt danh chỉ gồm chữ, số, dấu chấm (.) hoặc gạch dưới (_)';
    }
    if (_startsOrEndsWithDotOrUnderscore.hasMatch(value)) {
      return 'Biệt danh không được bắt đầu hoặc kết thúc bằng . hoặc _';
    }

    return null;
  }
}
