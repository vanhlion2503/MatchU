import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/utils/otp_phone_formatter.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';
import 'package:pinput/pinput.dart';
import 'package:matchu_app/translations/auth_translations.dart';

class OtpEnrollView extends StatelessWidget {
  const OtpEnrollView({super.key});

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
          'Xác nhận OTP',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
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
                  child: Obx(
                    () => RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        children: [
                          TextSpan(
                            text: authTr('Mã xác thực đã được gửi đến số \n'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          TextSpan(
                            text: maskOtpPhoneNumber(c.fullPhoneNumber.value),
                            style: Theme.of(context).textTheme.bodyLarge!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final pinSize = ((constraints.maxWidth - 40) / 6).clamp(
                      46.0,
                      52.0,
                    );
                    final pinTheme = PinTheme(
                      width: pinSize,
                      height: 58,
                      textStyle: Theme.of(context).textTheme.headlineSmall,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    );

                    return Pinput(
                      length: 6,
                      controller: c.otpC,
                      keyboardType: TextInputType.number,
                      separatorBuilder: (_) => const SizedBox(width: 8),
                      defaultPinTheme: pinTheme,
                      focusedPinTheme: pinTheme.copyDecorationWith(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      submittedPinTheme: pinTheme.copyDecorationWith(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Obx(() {
                  final isLoading = c.isLoadingRegister.value;
                  return SizedBox(
                    width: double.infinity,
                    child: IgnorePointer(
                      ignoring: isLoading,
                      child: ElevatedButton(
                        onPressed: c.confirmEnrollOtp,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: isLoading ? 0 : 1,
                              child: const Text('Xác nhận'),
                            ),
                            if (isLoading)
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Obx(
                  () => TextButton(
                    onPressed:
                        c.resendEnrollOtpSeconds.value == 0
                            ? c.sendEnrollOtp
                            : null,
                    child: Text(
                      c.resendEnrollOtpSeconds.value == 0
                          ? "Gửi lại OTP"
                          : "Gửi lại sau ${c.resendEnrollOtpSeconds.value}s",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
