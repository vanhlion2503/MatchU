import 'package:flutter/material.dart' as material;
import 'package:get/get.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:matchu_app/translations/nearby_translations.dart';
import 'package:matchu_app/translations/matching_chat_translations.dart';
import 'package:matchu_app/translations/random_chat_translations.dart';
import 'package:matchu_app/translations/long_chat_translations.dart';
import 'package:matchu_app/translations/profile_translations.dart';
import 'package:matchu_app/translations/auth_translations.dart';

export 'package:flutter/material.dart' hide Text;

/// Drop-in Material [Text] that translates legacy static labels at build time.
///
/// New code should prefer semantic keys from `TranslationKeys`. This adapter
/// keeps existing `const Text('...')` calls localizable while the older screens
/// are migrated incrementally.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    if (textSpan != null) {
      return material.Text.rich(
        textSpan!,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }

    return material.Text(
      _translate(data!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel?.tr,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  String _translate(String source) {
    final authTranslation = authTr(source);
    if (authTranslation != source) return authTranslation;
    final profileTranslation = profileTr(source);
    if (profileTranslation != source) return profileTranslation;
    final longChatTranslation = longChatTr(source);
    if (longChatTranslation != source) return longChatTranslation;
    final randomChatTranslation = randomChatTr(source);
    if (randomChatTranslation != source) return randomChatTranslation;
    final matchingChatTranslation = matchingChatTr(source);
    if (matchingChatTranslation != source) return matchingChatTranslation;
    final nearbyTranslation = nearbyTr(source);
    if (nearbyTranslation != source) return nearbyTranslation;
    final postTranslation = postTr(source);
    if (postTranslation != source) return postTranslation;
    final exact = source.tr;
    if (exact != source || Get.locale?.languageCode != 'en') return exact;

    final patterns = <(RegExp, String Function(Match))>[
      (RegExp(r'^(\d+) trực tuyến$'), (m) => '${m[1]} online'),
      (RegExp(r'^·?\s*(\d+) đánh giá$'), (m) => '${m[1]} reviews'),
      (RegExp(r'^(\d+) phản hồi$'), (m) => '${m[1]} replies'),
      (RegExp(r'^Bình luận \((\d+)\)$'), (m) => 'Comments (${m[1]})'),
      (RegExp(r'^Gửi lại sau (\d+)s$'), (m) => 'Resend in ${m[1]}s'),
      (RegExp(r'^Câu (\d+)/(\d+)$'), (m) => 'Question ${m[1]}/${m[2]}'),
      (RegExp(r'^Kết thúc sau (\d+)s$'), (m) => 'Ends in ${m[1]}s'),
      (RegExp(r'^(\d+) điểm còn lại$'), (m) => '${m[1]} points remaining'),
      (
        RegExp(r'^Tìm thấy (\d+) người gần bạn$'),
        (m) => '${m[1]} people nearby',
      ),
      (RegExp(r'^Độ tương thích • (\d+)%$'), (m) => 'Compatibility • ${m[1]}%'),
    ];
    for (final (pattern, replacement) in patterns) {
      final match = pattern.firstMatch(source);
      if (match != null) return replacement(match);
    }
    return source;
  }
}
