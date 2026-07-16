import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/translations/random_chat_translations.dart';

void main() {
  test('Random Chat dictionaries contain identical keys', () {
    expect(
      randomChatVietnameseTranslations.keys.toSet(),
      randomChatEnglishTranslations.keys.toSet(),
    );
  });

  test('Random Chat quota labels follow English locale', () {
    Get.locale = const Locale('en', 'US');

    expect(randomChatTr('Bắt đầu tìm kiếm • 7/10'), 'Start searching • 7/10');
    expect(
      randomChatTr('Hết lượt hôm nay • 0/10'),
      'No turns left today • 0/10',
    );
  });

  test('Random Chat snackbar localizes title and message', () {
    final source =
        File('lib/views/chat/random_chat_view.dart').readAsStringSync();
    final snackbar = RegExp(
      r'Get\.snackbar\(([\s\S]{0,300}?)\);',
      multiLine: true,
    );

    for (final match in snackbar.allMatches(source)) {
      final arguments = match.group(1)!;
      expect(
        arguments.contains('matchingChatTr(') &&
            arguments.contains('randomChatTr('),
        isTrue,
        reason: 'Unlocalized Random Chat snackbar:\n$arguments',
      );
    }
  });

  test('Random Chat guide and passcode labels are registered', () {
    final source =
        File('lib/views/chat/random_chat_view.dart').readAsStringSync();
    final keys = AppTranslations().keys['en_US']!.keys.toSet();
    final guideStart = source.indexOf('static const Map<_GuideTab');
    final guideEnd = source.indexOf('late final AnimationController');
    final guideSource = source.substring(guideStart, guideEnd);
    final quoted = RegExp(r'''(['"])([^'"\r\n]+)\1''');
    final namedArgument = RegExp(
      r'''(?:setupTitle|setupDescription|unlockTitle|unlockDescription):\s*(['"])([^'"\r\n]+)\1''',
    );
    final missing = <String>{};

    void audit(Iterable<RegExpMatch> matches) {
      for (final match in matches) {
        final label = match.group(2)!.trim();
        if (RegExp(r'[A-Za-zÀ-ỹĐđ]').hasMatch(label) &&
            !label.contains(r'$') &&
            !keys.contains(label)) {
          missing.add(label);
        }
      }
    }

    audit(quoted.allMatches(guideSource));
    audit(namedArgument.allMatches(source));

    expect(
      missing,
      isEmpty,
      reason: 'Missing Random Chat labels:\n${missing.join('\n')}',
    );
  });
}
