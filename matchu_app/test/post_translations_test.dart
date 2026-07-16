import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';

void main() {
  test('Post translation dictionaries contain identical keys', () {
    expect(
      postVietnameseTranslations.keys.toSet(),
      postEnglishTranslations.keys.toSet(),
    );
  });

  test('Post snackbars localize both title and message', () {
    final roots = [
      Directory('lib/controllers/feed'),
      Directory('lib/views/feed'),
      File('lib/controllers/report/post_report_controller.dart'),
    ];
    final sources = <String>[];
    for (final root in roots) {
      if (root is File) {
        sources.add(root.readAsStringSync());
      } else if (root is Directory) {
        sources.addAll(
          root
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .map((file) => file.readAsStringSync()),
        );
      }
    }

    final snackbar = RegExp(
      r'Get\.snackbar\(([\s\S]{0,500}?)snackPosition:',
      multiLine: true,
    );
    for (final source in sources) {
      for (final match in snackbar.allMatches(source)) {
        final arguments = match.group(1)!;
        expect(
          arguments.contains('.tr') || arguments.contains('postTr('),
          isTrue,
          reason: 'Unlocalized Post snackbar:\n$arguments',
        );
      }
    }
  });

  test('Post tabs do not contain raw labels', () {
    final source =
        File('lib/views/feed/widgets/feed_header.dart').readAsStringSync();
    expect(
      RegExp(r'''Tab\(text:\s*['"][^'"]+['"]\s*\)''').hasMatch(source),
      isFalse,
    );
  });

  test('static Post labels passed through named arguments are registered', () {
    final keys = AppTranslations().keys['en_US']!.keys.toSet();
    final pattern = RegExp(
      r'''(?:title|subtitle|message|hintText|tooltip|label):\s*(['"])([^'"\r\n]+)\1''',
    );
    final missing = <String>{};
    final files = <File>[
      ...Directory('lib/views/feed')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      File('lib/views/report/post_report_bottom_sheet.dart'),
      File('lib/views/report/post_report_follow_up_sheet.dart'),
    ];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final label =
            match
                .group(2)!
                .replaceAllMapped(
                  RegExp(r'\\u([0-9a-fA-F]{4})'),
                  (value) =>
                      String.fromCharCode(int.parse(value[1]!, radix: 16)),
                )
                .trim();
        if (label.isNotEmpty &&
            !label.contains(r'$') &&
            RegExp(r'[A-Za-zÀ-ỹĐđ]').hasMatch(label) &&
            !keys.contains(label) &&
            !const {'Aa...', '400'}.contains(label)) {
          missing.add(label);
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'Missing Post labels:\n${missing.join('\n')}',
    );
  });

  test('relative Post time follows English locale', () {
    Get.locale = const Locale('en', 'US');
    final value = formatRelativeTime(
      DateTime.now().subtract(const Duration(minutes: 2)),
      withSuffix: true,
    );
    expect(value, '2 minutes ago');
  });
}
