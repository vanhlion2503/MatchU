import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/translations/auth_translations.dart';

void main() {
  setUpAll(() {
    Get.addTranslations(AppTranslations().keys);
  });

  test('Auth dictionaries contain identical keys', () {
    expect(
      authVietnameseTranslations.keys.toSet(),
      authEnglishTranslations.keys.toSet(),
    );
  });

  test('Firebase errors follow the selected locale', () {
    Get.locale = const Locale('en', 'US');
    expect(firebaseErrorToVietnamese('wrong-password'), 'Incorrect password.');
    expect(
      firebaseErrorToVietnamese('network-request-failed'),
      'Network error. Check your internet connection.',
    );

    Get.locale = const Locale('vi', 'VN');
    expect(
      firebaseErrorToVietnamese('wrong-password'),
      'Mật khẩu không chính xác.',
    );
  });

  test('Auth dynamic labels follow English locale', () {
    Get.locale = const Locale('en', 'US');
    expect(authTr('Gửi lại sau 42s'), 'Resend in 42s');
    expect(
      authTr('Không thể hủy luồng đăng ký: network error'),
      'Unable to cancel registration: network error',
    );
  });

  test('Auth snackbars localize title and message', () {
    final files = <File>[
      File('lib/controllers/auth/auth_controller.dart'),
      File('lib/controllers/auth/forgot_password_controller.dart'),
      File('lib/controllers/auth/avatar_controller.dart'),
      File('lib/views/auth/verify_email_view.dart'),
    ];
    final snackbar = RegExp(
      r'Get\.snackbar\(([\s\S]{0,500}?)\);',
      multiLine: true,
    );

    for (final file in files) {
      for (final match in snackbar.allMatches(file.readAsStringSync())) {
        final arguments = match.group(1)!;
        expect(
          arguments.contains('authTr(') ||
              arguments.contains('firebaseErrorToVietnamese('),
          isTrue,
          reason: 'Unlocalized Auth snackbar in ${file.path}:\n$arguments',
        );
      }
    }
  });

  test('Auth RichText spans use localized content', () {
    final files = <File>[
      File('lib/views/auth/otp_enroll_view.dart'),
      File('lib/views/auth/otp_login_view.dart'),
      File('lib/views/auth/verify_email_view.dart'),
    ];
    final rawSpan = RegExp(r'''(?:const\s+)?TextSpan\(\s*text:\s*['"]''');

    for (final file in files) {
      expect(
        rawSpan.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: 'Raw TextSpan remains in ${file.path}',
      );
    }
  });

  test('static Auth snackbar labels are registered', () {
    final keys = AppTranslations().keys['en_US']!.keys.toSet();
    final source =
        File('lib/controllers/auth/auth_controller.dart').readAsStringSync();
    final call = RegExp(
      r'_showAuthSnackbar\(([\s\S]{0,300}?)\);',
      multiLine: true,
    );
    final literal = RegExp(r'''(['"])([^'"\r\n]+)\1''');
    final missing = <String>{};

    for (final match in call.allMatches(source)) {
      for (final value in literal.allMatches(match.group(1)!)) {
        final label =
            value
                .group(2)!
                .replaceAllMapped(
                  RegExp(r'\\u([0-9a-fA-F]{4})'),
                  (match) => String.fromCharCode(
                    int.parse(match.group(1)!, radix: 16),
                  ),
                )
                .trim();
        if (label.isNotEmpty &&
            !label.contains(r'$') &&
            RegExp(r'[A-Za-zÀ-ỹĐđ]').hasMatch(label) &&
            !keys.contains(label)) {
          missing.add(label);
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing static Auth labels:\n${missing.join('\n')}',
    );
  });

  test('Register labels use exact translation keys', () {
    final source = File('lib/views/auth/register_view.dart').readAsStringSync();

    expect(source, isNot(contains('" Email"')));
    expect(source, isNot(contains('" Mật khẩu"')));
    expect(source, isNot(contains('" Nhập lại mật khẩu:"')));
    expect(source, contains('"Email".tr'));
    expect(source, contains('"Mật khẩu".tr'));
    expect(source, contains('"Nhập lại mật khẩu".tr'));
  });
}
