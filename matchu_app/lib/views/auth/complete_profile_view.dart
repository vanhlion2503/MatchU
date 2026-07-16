import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/utils/profile_input_validator.dart';
import 'package:matchu_app/views/auth/show_avatar_bottom_sheet_auth.dart';
import 'package:matchu_app/widgets/dob_box.dart';
import 'package:matchu_app/widgets/gender_widget.dart';
import 'package:matchu_app/widgets/interest_tag_selector.dart';

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
        onTap: () => _dismissInputs(c),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _AvatarPicker(),
                SizedBox(height: 16),
                _FullnameField(),
                SizedBox(height: 16),
                _NicknameField(),
                SizedBox(height: 16),
                _BirthdayField(),
                SizedBox(height: 16),
                _GenderField(),
                SizedBox(height: 20),
                _InterestsField(),
                SizedBox(height: 46),
                _SaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissInputs(AuthController c) {
    FocusManager.instance.primaryFocus?.unfocus();
    c.selectedDobField.value = null;
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Center(
      child: Obx(() {
        final file = c.tempAvatarFile.value;
        final isBusy = c.isUploadingAvatar.value || c.isLoadingRegister.value;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap:
              isBusy
                  ? null
                  : () => showAvatarBottomSheetAuth(
                    context,
                    onPick: c.pickTempAvatar,
                    onPickFile: c.pickTempAvatarFile,
                  ),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                _AvatarCircle(file: file),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: IgnorePointer(
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (c.isUploadingAvatar.value) const _AvatarLoadingOverlay(),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.file});

  final File? file;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DottedBorder(
        borderType: BorderType.Circle,
        dashPattern: const [6, 6],
        color: Colors.grey.shade400,
        strokeWidth: 2,
        child: Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child:
              file != null
                  ? ClipOval(
                    child: Image.file(
                      file!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  )
                  : Icon(Iconsax.camera, size: 36, color: Colors.grey.shade500),
        ),
      ),
    );
  }
}

class _AvatarLoadingOverlay extends StatelessWidget {
  const _AvatarLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}

class _FullnameField extends StatelessWidget {
  const _FullnameField();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel("Họ và tên"),
        const SizedBox(height: 12),
        TextField(
          controller: c.fullnameC,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          maxLength: ProfileInputValidator.maxFullnameLength,
          inputFormatters: ProfileInputValidator.fullnameInputFormatters,
          onChanged: c.onFullnameChanged,
          decoration: InputDecoration(
            labelText: "Họ và tên".tr,
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
      ],
    );
  }
}

class _NicknameField extends StatelessWidget {
  const _NicknameField();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel("Biệt danh"),
        const SizedBox(height: 12),
        TextField(
          controller: c.nicknameC,
          textInputAction: TextInputAction.done,
          maxLength: ProfileInputValidator.maxNicknameLength,
          inputFormatters: ProfileInputValidator.nicknameInputFormatters,
          onChanged: c.onNicknameChanged,
          decoration: const InputDecoration(
            labelText: "@username",
            prefixIcon: Icon(Icons.tag_faces_outlined),
          ),
        ),
        const _NicknameStatus(),
      ],
    );
  }
}

class _NicknameStatus extends StatelessWidget {
  const _NicknameStatus();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Obx(() {
      final isChecking = c.isCheckingNickname.value;
      final message =
          isChecking
              ? "Đang kiểm tra nickname..."
              : c.nicknameCheckMessage.value;

      if (message.isEmpty) return const SizedBox.shrink();

      final color =
          isChecking
              ? Colors.grey.shade600
              : c.isNicknameAvailable.value == true
              ? Colors.green.shade700
              : c.isNicknameAvailable.value == false
              ? Colors.red.shade700
              : Colors.orange.shade700;

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            if (isChecking) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _BirthdayField extends StatelessWidget {
  const _BirthdayField();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel("Ngày sinh"),
        const SizedBox(height: 12),
        Obx(() {
          final d = c.selectedDay.value;
          final m = c.selectedMonth.value;
          final y = c.selectedYear.value;
          final activeField = c.selectedDobField.value;

          return Row(
            children: [
              dobBox(
                context,
                label: d != null ? d.toString().padLeft(2, '0') : "DD",
                active: activeField == DobField.day,
                onTap: () => openDayPicker(context, c),
              ),
              const SizedBox(width: 12),
              dobBox(
                context,
                label: m != null ? m.toString().padLeft(2, '0') : "MM",
                active: activeField == DobField.month,
                onTap: () => openMonthPicker(context, c),
              ),
              const SizedBox(width: 12),
              dobBox(
                context,
                label: y != null ? y.toString() : "YYYY",
                flex: 2,
                active: activeField == DobField.year,
                onTap: () => openYearPicker(context, c),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _GenderField extends StatelessWidget {
  const _GenderField();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel("Giới tính"),
        const SizedBox(height: 12),
        Obx(() {
          final selectedGender = c.selectedGender.value;

          return Row(
            children: [
              genderButton(
                context,
                label: "Nam",
                value: "male",
                isSelected: selectedGender == "male",
                onTap: () => c.selectedGender.value = "male",
              ),
              const SizedBox(width: 12),
              genderButton(
                context,
                label: "Nữ",
                value: "female",
                isSelected: selectedGender == "female",
                onTap: () => c.selectedGender.value = "female",
              ),
              const SizedBox(width: 12),
              genderButton(
                context,
                label: "Khác",
                value: "other",
                isSelected: selectedGender == "other",
                onTap: () => c.selectedGender.value = "other",
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _InterestsField extends StatelessWidget {
  const _InterestsField();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel("Sở thích của bạn"),
        const SizedBox(height: 12),
        Obx(
          () => InterestTagSelector(
            controller: c.interestC,
            selectedTags: c.selectedInterests.toList(growable: false),
            enabled: !c.isLoadingRegister.value,
            onAddTag: c.addInterest,
            onRemoveTag: c.removeInterest,
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Obx(() {
        final isSavingProfile = c.isLoadingRegister.value;
        final isSaveDisabled =
            c.isUploadingAvatar.value ||
            c.isCheckingNickname.value ||
            c.isNicknameAvailable.value == false ||
            c.tempAvatarFile.value == null;

        return IgnorePointer(
          ignoring: isSavingProfile,
          child: ElevatedButton(
            onPressed: isSaveDisabled ? null : c.saveProfile,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: isSavingProfile ? 0 : 1,
                  child: const Text(
                    "Lưu thông tin",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isSavingProfile)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
