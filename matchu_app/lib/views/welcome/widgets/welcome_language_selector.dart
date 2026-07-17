import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/system/language_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/translations/translation_keys.dart';

/// Compact locale selector used before the user signs in.
class WelcomeLanguageSelector extends GetView<LanguageController> {
  const WelcomeLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedCode = controller.languageCode.value;

      return Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<String>(
          key: const Key('welcome_language_selector'),
          tooltip: TranslationKeys.selectLanguage.tr,
          initialValue: selectedCode,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (code) => controller.changeLanguage(code),
          itemBuilder:
              (context) => [
                _buildLanguageItem(
                  context: context,
                  code: LanguageController.vietnameseCode,
                  label: TranslationKeys.vietnamese.tr,
                  selectedCode: selectedCode,
                ),
                _buildLanguageItem(
                  context: context,
                  code: LanguageController.englishCode,
                  label: TranslationKeys.english.tr,
                  selectedCode: selectedCode,
                ),
              ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _flagFor(selectedCode),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 5),
                Text(
                  selectedCode.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 1),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  PopupMenuItem<String> _buildLanguageItem({
    required BuildContext context,
    required String code,
    required String label,
    required String selectedCode,
  }) {
    final isSelected = code == selectedCode;

    return PopupMenuItem<String>(
      value: code,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_flagFor(code), style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 16),
            const Icon(
              Icons.check_rounded,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  String _flagFor(String code) {
    return code == LanguageController.englishCode ? '🇬🇧' : '🇻🇳';
  }
}
