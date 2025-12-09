import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/widgets/gender_widget.dart';

class CompleteProfileView extends StatelessWidget {
  const CompleteProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: 
        Text(
          "Hoàn thiện hồ sơ",
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                " Họ và tên",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c.fullnameC,
                  decoration: const InputDecoration(
                    labelText: "Họ và tên",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                " Biệt danh",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c.nicknameC,
                  decoration: const InputDecoration(
                    labelText: "@usename",
                    prefixIcon: Icon(Icons.tag_faces_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                " Ngày sinh",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                )
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: c.selectedBirthday.value ?? DateTime(2005),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );

                    if (picked != null) {
                      c.selectedBirthday.value = picked;

                      c.birthdayC.text = DateFormat('dd/MM/yyyy').format(picked);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: c.birthdayC, // ✅ GÁN CONTROLLER
                      decoration: const InputDecoration(
                        labelText: "Ngày sinh",
                        prefixIcon: Icon(Icons.cake_outlined),
                        hintText: "Chọn ngày sinh",
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                " Giới tính",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                )
                ),
                const SizedBox(height: 12),

                /// ===== GIỚI TÍNH =====
                Obx(() => Row(
                  children: [
                    genderButton(
                      context,
                      label: "Nam",
                      value: "male",
                      isSelected: c.selectedGender.value == "male",
                      onTap: () => c.selectedGender.value = "male",
                    ),
                    const SizedBox(width: 12),
                    genderButton(
                      context,
                      label: "Nữ",
                      value: "female",
                      isSelected: c.selectedGender.value == "female",
                      onTap: () => c.selectedGender.value = "female",
                    ),
                    const SizedBox(width: 12),
                    genderButton(
                      context,
                      label: "Khác",
                      value: "other",
                      isSelected: c.selectedGender.value == "other",
                      onTap: () => c.selectedGender.value = "other",
                    ),
                  ],
                )),

                const SizedBox(height: 46),

                /// ===== NÚT LƯU =====
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: c.isLoadingRegister.value
                        ? null
                        : c.saveProfile,
                    child: c.isLoadingRegister.value
                        ? CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : const Text(
                            "Lưu thông tin",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
