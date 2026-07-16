import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/translations/long_chat_translations.dart';

void main() {
  setUpAll(() {
    Get.addTranslations(AppTranslations().keys);
  });

  test('Long Chat dictionaries contain identical keys', () {
    expect(
      longChatVietnameseTranslations.keys.toSet(),
      longChatEnglishTranslations.keys.toSet(),
    );
  });

  test('Long Chat dynamic labels follow English locale', () {
    Get.locale = const Locale('en', 'US');

    expect(longChatTr('4 phút trước'), '4 minutes ago');
    expect(longChatTr('2 phút 8 giây'), '2 min 8 sec');
    expect(
      longChatTr('Cuộc gọi video • 2 phút 8 giây'),
      'Video call • 2 min 8 sec',
    );
    expect(longChatTr('Đã bỏ lỡ cuộc gọi thoại'), 'Missed voice call');
  });

  test('chat preview localizes UI without changing user content', () {
    Get.locale = const Locale('en', 'US');

    expect(
      longChatPreview('Hello from MatchU', isMe: true),
      'You: Hello from MatchU',
    );
    expect(longChatPreview('Ảnh', isMe: false), 'Image');
  });

  test('Chat List and Long Chat snackbars localize their content', () {
    final files = <File>[
      File('lib/controllers/chat/chat_controller.dart'),
      File('lib/controllers/chat/call_controller.dart'),
      File('lib/views/chat/long_chat/chat_view.dart'),
    ];
    final snackbar = RegExp(
      r'Get\.snackbar\(([\s\S]{0,500}?)\);',
      multiLine: true,
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in snackbar.allMatches(source)) {
        final arguments = match.group(1)!;
        expect(
          arguments.contains('longChatTr('),
          isTrue,
          reason: 'Unlocalized snackbar in ${file.path}:\n$arguments',
        );
      }
    }
  });

  test('dynamic PIN and call messages are registered', () {
    final keys = AppTranslations().keys['en_US']!.keys.toSet();
    final missing = <String>{};
    final pinSource =
        File(
          'lib/views/chat/list_chat/passcode_prompt_dialog.dart',
        ).readAsStringSync();
    final callSource =
        File('lib/controllers/chat/call_controller.dart').readAsStringSync();

    final vietnameseLiteral = RegExp(
      r'''(['"])([^'"\r\n]*[À-ỹĐđ][^'"\r\n]*)\1''',
    );
    for (final match in vietnameseLiteral.allMatches(pinSource)) {
      final label = match.group(2)!.trim();
      if (label.isNotEmpty && !label.contains(r'$') && !keys.contains(label)) {
        missing.add(label);
      }
    }

    final callError = RegExp(r'''_setError\(\s*(['"])([^'"\r\n]+)\1''');
    for (final match in callError.allMatches(callSource)) {
      final label =
          match
              .group(2)!
              .replaceAllMapped(
                RegExp(r'\\u([0-9a-fA-F]{4})'),
                (value) => String.fromCharCode(int.parse(value[1]!, radix: 16)),
              )
              .trim();
      if (!keys.contains(label)) missing.add(label);
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing dynamic Long Chat labels:\n${missing.join('\n')}',
    );
  });

  test('static Chat List and Long Chat named labels are registered', () {
    final keys = AppTranslations().keys['en_US']!.keys.toSet();
    final files = <File>[
      ...Directory('lib/views/chat/list_chat')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      ...Directory('lib/views/chat/long_chat')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
    ];
    final pattern = RegExp(
      r'''(?:title|subtitle|message|hintText|tooltip|label|semanticsLabel):\s*(['"])([^'"\r\n]+)\1''',
    );
    final missing = <String>{};

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final label = match.group(2)!.trim();
        if (label.isNotEmpty &&
            !label.contains(r'$') &&
            RegExp(r'[A-Za-zÀ-ỹĐđ]').hasMatch(label) &&
            !keys.contains(label) &&
            !const {'Aa...'}.contains(label)) {
          missing.add(label);
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing static Long Chat labels:\n${missing.join('\n')}',
    );
  });
}
