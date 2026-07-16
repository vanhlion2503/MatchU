import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/system/language_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/translations/translation_keys.dart';

class LanguageView extends GetView<LanguageController> {
  const LanguageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationKeys.language.tr)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Obx(
            () => _LanguageTile(
              title: TranslationKeys.vietnamese.tr,
              flag: '🇻🇳',
              selected:
                  controller.languageCode.value ==
                  LanguageController.vietnameseCode,
              onTap:
                  () => controller.changeLanguage(
                    LanguageController.vietnameseCode,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => _LanguageTile(
              title: TranslationKeys.english.tr,
              flag: '🇺🇸',
              selected:
                  controller.languageCode.value ==
                  LanguageController.englishCode,
              onTap:
                  () =>
                      controller.changeLanguage(LanguageController.englishCode),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final borderColor = selected ? AppTheme.primaryColor : secondaryColor;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppTheme.primaryColor : borderColor,
                    width: 2,
                  ),
                ),
                child:
                    selected
                        ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
