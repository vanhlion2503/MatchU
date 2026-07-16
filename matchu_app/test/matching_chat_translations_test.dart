import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/translations/game_content_translations.dart';
import 'package:matchu_app/translations/matching_chat_translations.dart';

void main() {
  test('Matching and Temp Chat dictionaries contain identical keys', () {
    expect(
      matchingChatVietnameseTranslations.keys.toSet(),
      matchingChatEnglishTranslations.keys.toSet(),
    );
    expect(
      gameContentVietnameseTranslations.keys.toSet(),
      gameContentEnglishTranslations.keys.toSet(),
    );
  });

  test('Matching and Temp Chat dynamic labels follow English locale', () {
    Get.locale = const Locale('en', 'US');

    expect(
      matchingChatTr('Nhập từ bắt đầu bằng "mưa"'),
      'Enter a phrase starting with "mưa"',
    );
    expect(matchingChatTr('Vượt quá 120 ký tự.'), 'Maximum 120 characters.');
    expect(matchingChatTr('3/5 câu trùng khớp'), '3/5 matching answers');
  });

  test('Matching and Temp Chat snackbars localize their content', () {
    final files = <File>[
      File('lib/controllers/matching/matching_controller.dart'),
      File('lib/controllers/chat/temp_chat_controller.dart'),
      File('lib/views/matching/match_transition_view.dart'),
      File('lib/views/chat/temp_chat/messages_list.dart'),
      File('lib/views/chat/temp_chat/word_chain/word_chain_playing_bar.dart'),
    ];
    final snackbar = RegExp(
      r'Get\.snackbar\(([\s\S]{0,400}?)\);',
      multiLine: true,
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in snackbar.allMatches(source)) {
        final arguments = match.group(1)!;
        expect(
          arguments.contains('matchingChatTr(') || arguments.contains('.tr'),
          isTrue,
          reason: 'Unlocalized snackbar in ${file.path}:\n$arguments',
        );
      }
    }
  });

  test('model-backed game labels are registered', () {
    final keys = AppTranslations().keys['en_US']!.keys.toSet();
    final files = <File>[
      File('lib/controllers/chat/temp_chat_controller.dart'),
      File('lib/controllers/game/telepathy/telepathy_question_bank.dart'),
      File('lib/views/chat/temp_chat/word_chain/word_chain_reward_data.dart'),
    ];
    final pattern = RegExp(
      r'''(?:text|prompt|description|left|right):\s*(['"])([^'"\r\n]+)\1''',
    );
    final missing = <String>{};

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final label = match.group(2)!.trim();
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
      reason: 'Missing model-backed game labels:\n${missing.join('\n')}',
    );
  });
}
