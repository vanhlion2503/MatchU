import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/auth/forgot_password_controller.dart';

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ForgotPasswordController());
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedPadding(
          // 🔥 tránh keyboard che nội dung
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset > 0 ? 16 : 0),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== ICON =====
                    Icon(
                      Iconsax.key,
                      size: 36,
                      color: Theme.of(context).iconTheme.color,
                    ),

                    const SizedBox(height: 28),

                    // ===== TITLE =====
                    Text(
                      "Quên mật khẩu?",
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 10),

                    // ===== DESCRIPTION =====
                    Text(
                      "Đừng lo lắng! Chúng tôi sẽ gửi cho bạn hướng dẫn đặt lại mật khẩu qua email đã đăng ký.",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(height: 1.5),
                    ),

                    const SizedBox(height: 40),

                    // ===== EMAIL LABEL =====
                    Text(
                      "Địa chỉ email",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===== EMAIL INPUT =====
                    Obx(
                      () => TextField(
                        controller: c.emailC,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        enabled: !c.isLoading.value, // 🔒 disable khi loading
                        onSubmitted: (_) {
                          if (!c.isLoading.value) {
                            c.sendResetEmail();
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: "ten@email.com",
                          prefixIcon: Icon(Iconsax.sms),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ===== SUBMIT BUTTON =====
                    Obx(() {
                      final isLoading = c.isLoading.value;
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: IgnorePointer(
                          ignoring: isLoading,
                          child: ElevatedButton(
                            onPressed: c.sendResetEmail,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: isLoading ? 0 : 1,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Gửi email đặt lại mật khẩu'),
                                      SizedBox(width: 8),
                                      Icon(Iconsax.arrow_right_3, size: 18),
                                    ],
                                  ),
                                ),
                                if (isLoading)
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 32),

                    // ===== BACK =====
                    Center(
                      child: TextButton.icon(
                        onPressed: c.isLoading.value ? null : () => Get.back(),
                        icon: const Icon(Iconsax.arrow_left_2),
                        label: const Text("Quay lại đăng nhập"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
