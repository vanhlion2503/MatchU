import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/feed/post_search_result.dart';

void main() {
  test('maps backend match types to the correct UI labels', () {
    expect(
      PostSearchMatchType.fromApi('exact_sentence'),
      PostSearchMatchType.exactSentence,
    );
    expect(
      PostSearchMatchType.fromApi('hashtag_only').label,
      'Khớp hashtag',
    );
    expect(
      PostSearchMatchType.fromApi('all_terms').label,
      'Khớp tất cả từ',
    );
  });
}
