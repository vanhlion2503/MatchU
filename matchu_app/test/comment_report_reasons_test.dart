import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/comment_report_reason.dart';
import 'package:matchu_app/translations/post_translations.dart';

void main() {
  test('comment report categories and reasons use unique stable keys', () {
    final categoryKeys =
        commentReportCategories.map((item) => item.key).toList();
    final reasonKeys =
        commentReportCategories
            .expand((category) => category.reasons)
            .map((reason) => reason.key)
            .toList();

    expect(categoryKeys.toSet(), hasLength(categoryKeys.length));
    expect(reasonKeys.toSet(), hasLength(reasonKeys.length));
    expect(commentReportCategories, hasLength(greaterThanOrEqualTo(6)));
    expect(
      commentReportCategories.every((category) => category.reasons.isNotEmpty),
      isTrue,
    );
  });

  test(
    'all comment report labels have Vietnamese and English translations',
    () {
      final labels = <String>{
        for (final category in commentReportCategories) category.title,
        for (final category in commentReportCategories)
          for (final reason in category.reasons) reason.title,
      };

      expect(
        labels.difference(postVietnameseTranslations.keys.toSet()),
        isEmpty,
      );
      expect(labels.difference(postEnglishTranslations.keys.toSet()), isEmpty);
    },
  );

  test('every category provides an explicit fallback reason', () {
    expect(
      commentReportCategories.every(
        (category) =>
            category.reasons.any((reason) => reason.requiresCustomReason),
      ),
      isTrue,
    );
  });
}
