import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/user/account_settings_controller.dart';
import 'package:matchu_app/views/setting/widgets/dob_box_edit.dart';
import 'package:matchu_app/widgets/dob_box.dart';
import 'package:matchu_app/widgets/gender_widget.dart';

class EditProfileView extends StatelessWidget {
  const EditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AccountSettingsController>();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Chỉnh sửa hồ sơ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          c.selectedDobField.value = null;
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Obx(() {

              if (c.isLoadingInitial.value) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HỌ TÊN =================
                  const Text(
                    "Họ và tên",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c.fullnameC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Họ và tên",
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ================= NICKNAME =================
                  const Text(
                    "Biệt danh",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c.nicknameC,
                    decoration: const InputDecoration(
                      labelText: "@username",
                      prefixIcon: Icon(Icons.tag_faces_outlined),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================= NGÀY SINH =================
                  const Text(
                    "Ngày sinh",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      dobBoxEdit(
                        context,
                        label: c.selectedDay.value
                                ?.toString()
                                .padLeft(2, '0') ??
                            "DD",
                        active: c.selectedDobField.value == DobField.day,
                        onTap: () => openEditDayPicker(context, c),
                      ),
                      const SizedBox(width: 12),
                      dobBoxEdit(
                        context,
                        label: c.selectedMonth.value
                                ?.toString()
                                .padLeft(2, '0') ??
                            "MM",
                        active: c.selectedDobField.value == DobField.month,
                        onTap: () => openEditMonthPicker(context, c),
                      ),
                      const SizedBox(width: 12),
                      dobBoxEdit(
                        context,
                        label:
                            c.selectedYear.value?.toString() ?? "YYYY",
                        flex: 2,
                        active: c.selectedDobField.value == DobField.year,
                        onTap: () => openEditYearPicker(context, c),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ================= GIỚI TÍNH =================
                  const Text(
                    "Giới tính",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      genderButton(
                        context,
                        label: "Nam",
                        value: "male",
                        isSelected:
                            c.selectedGender.value == "male",
                        onTap: () =>
                            c.selectedGender.value = "male",
                      ),
                      const SizedBox(width: 12),
                      genderButton(
                        context,
                        label: "Nữ",
                        value: "female",
                        isSelected:
                            c.selectedGender.value == "female",
                        onTap: () =>
                            c.selectedGender.value = "female",
                      ),
                      const SizedBox(width: 12),
                      genderButton(
                        context,
                        label: "Khác",
                        value: "other",
                        isSelected:
                            c.selectedGender.value == "other",
                        onTap: () =>
                            c.selectedGender.value = "other",
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // ================= SAVE =================
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          c.isSaving.value || !c.hasChanged ? null : c.save,
                      child: c.isSaving.value
                          ? const CircularProgressIndicator()
                          : const Text(
                              "Lưu thay đổi",
                              style:
                                  TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

