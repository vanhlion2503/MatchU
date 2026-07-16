import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/system/theme_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/translations/translation_keys.dart';

class DisplayModeView extends StatelessWidget {
  const DisplayModeView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeC = Get.find<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: Text(TranslationKeys.displayMode.tr)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationKeys.appearance.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 16),

            // ===== KHUNG LỰA CHỌN =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                ),
              ),
              child: Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 🔆 LIGHT MODE
                    _themeOption(
                      title: TranslationKeys.light.tr,
                      isSelected: themeC.themeMode.value == "light",
                      preview: _lightPreview(),
                      onTap: () => themeC.setLight(),
                    ),

                    // 🌙 DARK MODE
                    _themeOption(
                      title: TranslationKeys.dark.tr,
                      isSelected: themeC.themeMode.value == "dark",
                      preview: _darkPreview(),
                      onTap: () => themeC.setDark(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CARD CHỌN THEME ====================
  Widget _themeOption({
    required String title,
    required bool isSelected,
    required Widget preview,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          preview,
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Radio chọn
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected
                            ? AppTheme.primaryColor
                            : (isDark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder),
                    width: 2,
                  ),
                ),
                child:
                    isSelected
                        ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                        : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== PREVIEW LIGHT ====================
  Widget _lightPreview() {
    return Container(
      width: 110,
      height: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.lightBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Container(height: 40, color: AppTheme.lightSurface),
          const SizedBox(height: 8),
          Expanded(
            child: Container(color: AppTheme.lightBorder.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  // ==================== PREVIEW DARK ====================
  Widget _darkPreview() {
    return Container(
      width: 110,
      height: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Container(height: 40, color: AppTheme.darkSurface),
          const SizedBox(height: 8),
          Expanded(
            child: Container(color: AppTheme.darkBorder.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}
