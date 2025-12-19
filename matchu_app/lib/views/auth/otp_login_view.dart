import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';
import 'package:pinput/pinput.dart';

class OtpLoginView extends StatelessWidget {
  const OtpLoginView({super.key});

  String maskPhone(String phone) {
    if (phone.isEmpty || phone.length < 6) return phone;

    final start = phone.substring(0, 3);
    final end = phone.substring(phone.length - 4); 

    return '$start***$end';
  }
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
        title: 
        Text('Xác nhận OTP',
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        )
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
            children: [
              const Icon(Icons.verified, size: 80),
              const SizedBox(height: 24),
              Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      children: [
                        TextSpan(
                          text: 'Mã xác thực đã được gửi đến số \n',
                          style: Theme.of(context).textTheme.bodyLarge
                        ),
                        TextSpan(
                          text: maskPhone(c.fullPhoneNumber.value.trim()),
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Pinput(
                length: 6, // ✅ 6 ô
                controller: c.otpC,
                keyboardType: TextInputType.number,

                defaultPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: Theme.of(context).textTheme.headlineSmall,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                ),

                focusedPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: Theme.of(context).textTheme.headlineSmall,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),

                submittedPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: Theme.of(context).textTheme.headlineSmall,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: c.isLoadingLogin.value ? null : c.confirmLogOtp,
                  child: c.isLoadingLogin.value
                  ? const CircularProgressIndicator()
                  : const Text('Xác nhận'),
                ),
              )),
              const SizedBox(height: 8),
              Obx(() => TextButton(
                onPressed: c.resendLoginOtpSeconds.value == 0
                    ? c.sendEnrollOtp
                    : null,
                child: Text(
                  c.resendLoginOtpSeconds.value == 0
                      ? "Gửi lại mã"
                      : "Gửi lại sau ${c.resendLoginOtpSeconds.value}s",
                ),
              )),
            ],
            ),
          ),
        ),
      ),
    );
  }
}