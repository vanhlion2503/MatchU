import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:intl/intl.dart';

class CompleteProfileView extends StatelessWidget {
  const CompleteProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hoàn thiện hồ sơ"),
        centerTitle: true,
        automaticallyImplyLeading: false, // không cho back
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// ===== HỌ TÊN =====
                TextField(
                  controller: c.fullnameC,
                  decoration: const InputDecoration(
                    labelText: "Họ và tên",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== NICKNAME =====
                TextField(
                  controller: c.nicknameC,
                  decoration: const InputDecoration(
                    labelText: "Nickname",
                    prefixIcon: Icon(Icons.tag_faces_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== NGÀY SINH =====
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2005),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      c.selectedBirthday.value = picked;
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: "Ngày sinh",
                        prefixIcon: const Icon(Icons.cake_outlined),
                        hintText: c.selectedBirthday.value == null
                            ? "Chọn ngày sinh"
                            : DateFormat('dd/MM/yyyy')
                                .format(c.selectedBirthday.value!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== GIỚI TÍNH =====
                DropdownButtonFormField<String>(
                  value: c.selectedGender.value.isEmpty
                      ? null
                      : c.selectedGender.value,
                  decoration: const InputDecoration(
                    labelText: "Giới tính",
                    prefixIcon: Icon(Icons.wc_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text("Nam")),
                    DropdownMenuItem(value: 'female', child: Text("Nữ")),
                    DropdownMenuItem(value: 'other', child: Text("Khác")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      c.selectedGender.value = value;
                    }
                  },
                ),
                const SizedBox(height: 16),

                /// ===== SỐ ĐIỆN THOẠI (READ ONLY) =====
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Số điện thoại",
                    prefixIcon: const Icon(Icons.phone_outlined),
                    hintText: c.fullPhoneNumber.value.isEmpty
                        ? "Chưa có số điện thoại"
                        : c.fullPhoneNumber.value,
                  ),
                ),

                const SizedBox(height: 32),

                /// ===== NÚT LƯU =====
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: c.isLoadingRegister.value
                        ? null
                        : c.saveProfile,
                    child: c.isLoadingRegister.value
                        ? const CircularProgressIndicator(
                            color: Colors.white,
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
