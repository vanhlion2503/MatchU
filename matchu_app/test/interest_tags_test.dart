import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/utils/interest_tags.dart';

void main() {
  test('every canonical interest tag has an English display label', () {
    expect(InterestTags.english.length, InterestTags.all.length);

    for (final tag in InterestTags.all) {
      expect(
        InterestTags.localizedLabel(tag, languageCode: 'en'),
        isNotEmpty,
        reason: 'Missing English label for $tag',
      );
    }
  });

  test('interest labels switch locale without changing stored values', () {
    const music = '🎵 Âm nhạc';

    expect(InterestTags.localizedLabel(music, languageCode: 'vi'), music);
    expect(InterestTags.localizedLabel(music, languageCode: 'en'), '🎵 Music');
    expect(InterestTags.normalizeList([music]), [music]);

    Get.locale = const Locale('en', 'US');
    expect(InterestTags.localizedLabel('📷 Nhiếp ảnh'), '📷 Photography');
    Get.locale = const Locale('vi', 'VN');
    expect(InterestTags.localizedLabel('📷 Nhiếp ảnh'), '📷 Nhiếp ảnh');
  });

  test('search accepts both Vietnamese and English labels', () {
    expect(InterestTags.search('nhiếp ảnh'), contains('📷 Nhiếp ảnh'));
    expect(InterestTags.search('photography'), contains('📷 Nhiếp ảnh'));
    expect(InterestTags.search('basketball'), contains('🏀 Bóng rổ'));
  });

  test('all interest chip renderers use localized labels', () {
    final files = [
      File('lib/widgets/interest_tag_selector.dart'),
      File('lib/widgets/profile_interests_wrap.dart'),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source.contains('InterestTags.localizedLabel(tag)'),
        isTrue,
        reason: '${file.path} renders a canonical tag directly',
      );
    }
  });
}
