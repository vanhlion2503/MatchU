import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:matchu_app/theme/app_theme.dart';

class EnrollPhoneView extends StatelessWidget {
  const EnrollPhoneView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: Text('Số điện thoại',
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.bold,
            ),
      )),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
                const Icon(Icons.phone, size: 80),
                const SizedBox(height: 24),
                Text("Chúng tôi cần số điện thoại của bạn để xác thực tài khoản và tăng cường bảo mật.",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                ),
                const SizedBox(height: 24),
                IntlPhoneField(
                    initialCountryCode: 'VN',
                    disableLengthCheck: true,
                    showDropdownIcon: true,
                    decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: 'Nhập số điện thoại',
                    ),
                    onChanged: (phone) {
                    c.fullPhoneNumber.value = phone.completeNumber;
                },
                ),
                const SizedBox(height: 24),
                Text('Chúng tôi sẽ mã OTP qua tin nhắn SMS',
                    textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                        ),
                    ),
                const SizedBox(height: 32),
                Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: c.isLoadingRegister.value
                          ? null
                          : c.sendEnrollOtp,
                      child: c.isLoadingRegister.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Gửi mã ngay'),
                    ),
                  )
                ),
            ],
          ),
        ),
      ),
    );
  }
}
