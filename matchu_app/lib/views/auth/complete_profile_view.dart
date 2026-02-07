import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/utils/profile_input_validator.dart';
import 'package:matchu_app/views/auth/show_avatar_bottom_sheet_auth.dart';
import 'package:matchu_app/widgets/gender_widget.dart';
import 'package:matchu_app/widgets/dob_box.dart';

class CompleteProfileView extends StatelessWidget {
  const CompleteProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Hoàn thiện hồ sơ",
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // 1️⃣ Tắt focus TextField
          FocusManager.instance.primaryFocus?.unfocus();

          // 2️⃣ Bỏ highlight DOB box
          c.selectedDobField.value = null;
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Obx(() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ================= AVATAR =================
                  Center(
                    child: Obx(() {
                      final file = c.tempAvatarFile.value;

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap:
                            () => showAvatarBottomSheetAuth(
                              context,
                              onPick: (source) => c.pickTempAvatar(source),
                            ),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Stack(
                            children: [
                              // ===== DOTTED BORDER =====
                              DottedBorder(
                                borderType: BorderType.Circle,
                                dashPattern: const [6, 6],
                                color: Colors.grey.shade400,
                                strokeWidth: 2,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child:
                                      file != null
                                          ? ClipOval(
                                            child: Image.file(
                                              file,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                          : Icon(
                                            Iconsax.camera,
                                            size: 36,
                                            color: Colors.grey.shade500,
                                          ),
                                ),
                              ),

                              // ===== PLUS ICON =====
                              Positioned(
                                bottom: 5,
                                right: 5,
                                child: IgnorePointer(
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                              // ===== LOADING (OPTIONAL) =====
                              if (c.isUploadingAvatar.value)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.35),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    " Họ và tên",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c.fullnameC,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    maxLength: ProfileInputValidator.maxFullnameLength,
                    inputFormatters:
                        ProfileInputValidator.fullnameInputFormatters,
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c.nicknameC,
                    textInputAction: TextInputAction.done,
                    maxLength: ProfileInputValidator.maxNicknameLength,
                    inputFormatters:
                        ProfileInputValidator.nicknameInputFormatters,
                    decoration: const InputDecoration(
                      labelText: "@username",
                      prefixIcon: Icon(Icons.tag_faces_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    "Ngày sinh",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Obx(() {
                    final d = c.selectedDay.value;
                    final m = c.selectedMonth.value;
                    final y = c.selectedYear.value;

                    return Row(
                      children: [
                        dobBox(
                          context,
                          label:
                              d != null ? d.toString().padLeft(2, '0') : "DD",
                          active: c.selectedDobField.value == DobField.day,
                          onTap: () => openDayPicker(context, c),
                        ),
                        const SizedBox(width: 12),
                        dobBox(
                          context,
                          label:
                              m != null ? m.toString().padLeft(2, '0') : "MM",
                          active: c.selectedDobField.value == DobField.month,
                          onTap: () => openMonthPicker(context, c),
                        ),
                        const SizedBox(width: 12),
                        dobBox(
                          context,
                          label: y != null ? y.toString() : "YYYY",
                          flex: 2,
                          active: c.selectedDobField.value == DobField.year,
                          onTap: () => openYearPicker(context, c),
                        ),
                      ],
                    );
                  }),

                  const SizedBox(height: 16),

                  Text(
                    " Giới tính",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  /// ===== GIỚI TÍNH =====
                  Obx(
                    () => Row(
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
                    ),
                  ),

                  const SizedBox(height: 46),

                  /// ===== NÚT LƯU =====
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed:
                          c.isLoadingRegister.value ||
                                  c.tempAvatarFile.value == null
                              ? null
                              : c.saveProfile,
                      child:
                          c.isLoadingRegister.value
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
      ),
    );
  }
}

