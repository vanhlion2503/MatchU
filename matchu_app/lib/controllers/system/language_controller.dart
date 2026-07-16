import 'dart:ui';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/translations/app_translations.dart';

class LanguageController extends GetxController {
  static const storageKey = 'languageCode';
  static const vietnameseCode = 'vi';
  static const englishCode = 'en';

  final GetStorage _storage;
  final RxString languageCode;

  LanguageController({GetStorage? storage})
    : _storage = storage ?? GetStorage(),
      languageCode = _initialLanguageCode(storage ?? GetStorage()).obs;

  static String _initialLanguageCode(GetStorage storage) {
    final saved = storage.read<String>(storageKey);
    if (saved != null &&
        AppTranslations.supportedLanguageCodes.contains(saved)) {
      return saved;
    }

    final deviceCode = Get.deviceLocale?.languageCode;
    return AppTranslations.supportedLanguageCodes.contains(deviceCode)
        ? deviceCode!
        : vietnameseCode;
  }

  Locale get locale => localeFor(languageCode.value);

  static Locale localeFor(String code) =>
      code == englishCode ? const Locale('en', 'US') : const Locale('vi', 'VN');

  Future<void> changeLanguage(String code) async {
    if (!AppTranslations.supportedLanguageCodes.contains(code) ||
        languageCode.value == code) {
      return;
    }
    languageCode.value = code;
    await _storage.write(storageKey, code);
    await Get.updateLocale(localeFor(code));
  }
}
