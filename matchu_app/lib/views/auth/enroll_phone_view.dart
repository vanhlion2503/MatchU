import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';

class EnrollPhoneView extends StatelessWidget {
  const EnrollPhoneView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 56, // 👈 đủ chỗ cho nút tròn
        leading: Align(
          alignment: Alignment.centerLeft,
          child: BackCircleButton(
            offset: const Offset(10, 0),
            size: 44,
            iconSize: 20,
          ),
        ),
        title: Text(
          'Số điện thoại',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.phone, size: 80),
              const SizedBox(height: 24),
              Text(
                "Chúng tôi cần số điện thoại của bạn để xác thực tài khoản và tăng cường bảo mật.",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
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
                  String number = phone.completeNumber;

                  // 🇻🇳 Fix riêng cho VN: +840xxx → +84xxx
                  if (number.startsWith('+840')) {
                    number = '+84' + number.substring(4);
                  }

                  c.fullPhoneNumber.value = number;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Chúng tôi sẽ mã OTP qua tin nhắn SMS',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Obx(() {
                final isLoading = c.isLoadingRegister.value;
                return SizedBox(
                  width: double.infinity,
                  child: IgnorePointer(
                    ignoring: isLoading,
                    child: ElevatedButton(
                      onPressed: c.sendEnrollOtp,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: isLoading ? 0 : 1,
                            child: const Text('Gửi mã ngay'),
                          ),
                          if (isLoading)
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
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
