import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/theme_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class DisplayModeView extends StatelessWidget {
  const DisplayModeView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeC = Get.find<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hiển thị"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hình thức",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 16),

            // ===== KHUNG LỰA CHỌN =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 🔆 LIGHT MODE
                      _themeOption(
                        title: "Sáng",
                        isSelected: themeC.themeMode.value == "light",
                        preview: _lightPreview(),
                        onTap: () => themeC.setLight(),
                      ),

                      // 🌙 DARK MODE
                      _themeOption(
                        title: "Tối",
                        isSelected: themeC.themeMode.value == "dark",
                        preview: _darkPreview(),
                        onTap: () => themeC.setDark(),
                      ),
                    ],
                  )),
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
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
                width: 2,
              ),
            ),
            child: isSelected
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Container(height: 40, color: Colors.grey[200]),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              color: Colors.grey[300],
            ),
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Container(height: 40, color: Colors.grey[800]),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
