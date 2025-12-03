import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/theme/app_theme.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final controllerRegis = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tạo tài khoản",
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            // const SizedBox(height: 6),
            Text(
              "Nhập thông tin để bắt đầu hành trình.",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(
                    color: const Color.fromARGB(255, 78, 87, 92),
                    fontWeight: FontWeight.w700,
                    ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 24),

              /// EMAIL
              TextField(
                controller: controllerRegis.emailC,
                decoration: const InputDecoration(
                  labelText: "Email",
                  hintText: "Nhập email của bạn",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 24),

              /// PASSWORD
              Obx(() {
                return TextField(
                  controller: controllerRegis.passwordC,
                  obscureText: controllerRegis.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: "Mật khẩu",
                    hintText: "Nhập mật khẩu",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controllerRegis.isPasswordHidden.value
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed:
                          controllerRegis.isPasswordHidden.toggle,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              /// CONFIRM PASSWORD
              Obx(() {
                return TextField(
                  controller: controllerRegis.confirmPasswordC,
                  obscureText:
                      controllerRegis.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: "Nhập lại mật khẩu",
                    hintText: "Nhập lại mật khẩu",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controllerRegis.isPasswordHidden.value
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: controllerRegis.isPasswordHidden.toggle,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              /// PHONE
              IntlPhoneField(
                initialCountryCode: 'VN',
                disableLengthCheck: true,
                showDropdownIcon: true,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: 'Nhập số điện thoại',
                ),
                onChanged: (phone) {
                  controllerRegis.fullPhoneNumber.value =
                      phone.completeNumber;
                },
              ),

              const SizedBox(height: 55),

              /// REGISTER BUTTON
              Obx(() {
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        controllerRegis.isLoadingRegister.value
                            ? null
                            : controllerRegis.register,
                    child: controllerRegis.isLoadingRegister.value
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : const Text("Đăng ký"),
                  ),
                );
              }),

              const SizedBox(height: 24),


              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Đã có tài khoản?",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(AppRouter.login);
                    },
                    child: Text(
                      "Đăng nhập",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
