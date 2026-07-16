import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/translations/localized_material.dart';

void main() {
  test('Vietnamese and English contain exactly the same translation keys', () {
    final translations = AppTranslations().keys;
    final vietnameseKeys = translations['vi_VN']!.keys.toSet();
    final englishKeys = translations['en_US']!.keys.toSet();

    expect(vietnameseKeys.difference(englishKeys), isEmpty);
    expect(englishKeys.difference(vietnameseKeys), isEmpty);
    expect(vietnameseKeys, isNotEmpty);
  });

  test('all translations are non-empty', () {
    for (final locale in AppTranslations().keys.entries) {
      for (final translation in locale.value.entries) {
        expect(
          translation.value.trim(),
          isNotEmpty,
          reason: '${locale.key}: ${translation.key}',
        );
      }
    }
  });

  test('all legacy static Text labels are registered', () {
    final knownKeys = AppTranslations().keys['en_US']!.keys.toSet();
    final staticText = RegExp(
      r'''\bText\(\s*(['"])([^'"\r\n]+)\1''',
      multiLine: true,
    );
    const ignored = <String>{
      'MatchU',
      'Google',
      'SOS',
      'OTP',
      'Email',
      'QR',
      'AI',
      '●',
      '✓',
      '?',
    };
    final missing = <String>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('translations/localized_material.dart')) continue;
      for (final match in staticText.allMatches(source)) {
        final label =
            match
                .group(2)!
                .replaceAll(r'\n', '\n')
                .replaceAllMapped(
                  RegExp(r'\\u([0-9a-fA-F]{4})'),
                  (value) =>
                      String.fromCharCode(int.parse(value[1]!, radix: 16)),
                )
                .trim();
        final hasLetter = RegExp(r'[A-Za-zÀ-ỹĐđ]').hasMatch(label);
        final isTemplate = label.contains(r'$');
        if (hasLetter &&
            !isTemplate &&
            !ignored.contains(label) &&
            !knownKeys.contains(label)) {
          missing.add(label);
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing static labels:\n${missing.join('\n')}',
    );
  });

  testWidgets('legacy Text labels react to the selected locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: Text('Đăng nhập')),
      ),
    );
    expect(find.text('Log in'), findsOneWidget);
  });
}
