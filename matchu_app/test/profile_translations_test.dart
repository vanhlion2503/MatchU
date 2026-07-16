import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/user_profile_report_reason.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/translations/profile_translations.dart';

void main() {
  setUpAll(() {
    Get.addTranslations(AppTranslations().keys);
  });

  test('Profile dictionaries contain identical keys', () {
    expect(
      profileVietnameseTranslations.keys.toSet(),
      profileEnglishTranslations.keys.toSet(),
    );
  });

  test('Profile dynamic messages follow English locale', () {
    Get.locale = const Locale('en', 'US');

    expect(
      profileTr('Họ và tên phải từ 2 đến 50 ký tự'),
      'Full name must be 2–50 characters long',
    );
    expect(
      profileTr('Chúng tôi sẽ xem xét tài khoản Minh.'),
      "We will review Minh's account.",
    );
    expect(
      profileTr('Ảnh QR đã được lưu tại /storage/matchu.png.'),
      'The QR image was saved to /storage/matchu.png.',
    );
    expect(
      profileTr(
        'Bạn có muốn chặn Minh không? Nếu chặn, bạn sẽ không còn thấy hồ sơ, bài viết và tin nhắn từ tài khoản này.',
      ),
      'Block Minh? You will no longer see this profile, their posts, or their messages.',
    );
  });

  test('all profile report categories and reasons are translated', () {
    final keys = profileEnglishTranslations.keys.toSet();
    final missing = <String>{};

    for (final category in userProfileReportCategories) {
      if (!keys.contains(category.title)) missing.add(category.title);
      for (final reason in category.reasons) {
        if (!keys.contains(reason.title)) missing.add(reason.title);
      }
    }

    expect(missing, isEmpty, reason: 'Missing report labels: $missing');
  });

  test('Profile snackbars route content through the profile translator', () {
    final files = <File>[
      File('lib/controllers/user/account_settings_controller.dart'),
      File('lib/controllers/report/user_profile_report_controller.dart'),
      File('lib/controllers/qr/profile_qr_controller.dart'),
      File('lib/controllers/profile/profile_posts_controller.dart'),
      File('lib/views/profile/profile_view.dart'),
      File('lib/views/profile/other_profile_view.dart'),
      File('lib/views/profile/widgets/profile_posts_section.dart'),
    ];
    final snackbar = RegExp(
      r'Get\.snackbar\(([\s\S]{0,700}?)\);',
      multiLine: true,
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in snackbar.allMatches(source)) {
        final arguments = match.group(1)!;
        expect(
          arguments.contains('profileTr('),
          isTrue,
          reason: 'Unlocalized snackbar in ${file.path}:\n$arguments',
        );
      }
    }
  });

  test('Profile tabs do not contain untranslated static text', () {
    final files = <File>[
      File('lib/views/profile/follow_tab_view.dart'),
      File('lib/views/profile/widgets/profile_posts_section.dart'),
      File('lib/views/setting/restriction_list_view.dart'),
    ];
    final rawTab = RegExp(r'''Tab\(text:\s*['"][^'"]+['"]\)''');

    for (final file in files) {
      expect(
        rawTab.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: 'Raw Tab label remains in ${file.path}',
      );
    }
  });
}
