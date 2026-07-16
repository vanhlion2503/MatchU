import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/utils/emoji_utils.dart';

void main() {
  test('recognizes common emoji sequences', () {
    expect(isEmojiOnlyText('❤️'), isTrue);
    expect(isEmojiOnlyText('👋🏽 👩‍💻'), isTrue);
    expect(isEmojiOnlyText('🇻🇳'), isTrue);
  });

  test('rejects empty and mixed text', () {
    expect(isEmojiOnlyText(''), isFalse);
    expect(isEmojiOnlyText('hello 👋'), isFalse);
    expect(isEmojiOnlyText('123'), isFalse);
  });
}
