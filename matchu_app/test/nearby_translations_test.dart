import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/translations/nearby_translations.dart';

void main() {
  test('Nearby translation dictionaries contain identical keys', () {
    expect(
      nearbyVietnameseTranslations.keys.toSet(),
      nearbyEnglishTranslations.keys.toSet(),
    );
  });

  test('Nearby dynamic labels follow English locale', () {
    Get.locale = const Locale('en', 'US');

    expect(nearbyTr('Cách 850m'), '850 m away');
    expect(nearbyTr('Cách 1.2km'), '1.2 km away');
    expect(nearbyTr('Tìm thấy 4 người gần bạn'), 'Found 4 people nearby');
  });

  test('Nearby snackbars localize title and message', () {
    final source =
        File(
          'lib/controllers/nearby/nearby_controller.dart',
        ).readAsStringSync();
    final snackbars = RegExp(
      r'Get\.snackbar\(([\s\S]{0,300}?)\);',
      multiLine: true,
    );

    for (final match in snackbars.allMatches(source)) {
      final arguments = match.group(1)!;
      expect(
        arguments.contains('.tr') && arguments.contains('nearbyTr('),
        isTrue,
        reason: 'Unlocalized Nearby snackbar:\n$arguments',
      );
    }
  });

  test('static Nearby labels are registered', () {
    final keys = AppTranslations().keys['en_US']!.keys.toSet();
    final files = <File>[
      ...Directory('lib/views/nearby')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      File('lib/controllers/nearby/nearby_controller.dart'),
      File('lib/services/nearby/nearby_service.dart'),
    ];
    final patterns = <RegExp>[
      RegExp(
        r'''(?:Text|title|subtitle|message|hintText|tooltip|actionLabel):?\s*\(?\s*(['"])([^'"\r\n]+)\1''',
      ),
      RegExp(
        r'''NearbyLocationException\([\s\S]{0,100}?(['"])([^'"\r\n]+)\1''',
      ),
      RegExp(r'''_setLocationError\(\s*(['"])([^'"\r\n]+)\1'''),
    ];
    final missing = <String>{};

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(source)) {
          final label = match.group(2)!.trim();
          if (label.isNotEmpty &&
              !label.contains(r'$') &&
              RegExp(r'[A-Za-zÀ-ỹĐđ]').hasMatch(label) &&
              !keys.contains(label) &&
              !const {'U'}.contains(label)) {
            missing.add(label);
          }
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing Nearby labels:\n${missing.join('\n')}',
    );
  });
}
