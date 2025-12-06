import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/theme/app_theme.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late AuthController controllerRegis;

  @override
  void initState() {
    super.initState();

    controllerRegis = Get.find<AuthController>();

    // ✅ RESET FORM KHI VÀO MÀN
    controllerRegis.emailC.clear();
    controllerRegis.passwordC.clear();
    controllerRegis.confirmPasswordC.clear();
    controllerRegis.otpC.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 80,
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
            SizedBox(height: 8),
            Text(
              "Nhập thông tin để bắt đầu hành trình.",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
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
              Text(
                " Email",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                )
                ),
              const SizedBox(height: 12),
              /// EMAIL
              TextField(
                controller: controllerRegis.emailC,
                decoration: const InputDecoration(
                  labelText: "Email",
                  hintText: "abc@xyz.com",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                " Mật khẩu",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                )
                ),
              const SizedBox(height: 12),
              /// PASSWORD
              Obx(() {
                return TextField(
                  controller: controllerRegis.passwordC,
                  obscureText: controllerRegis.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: "Mật khẩu",
                    hintText: "8+ | Aa | 0–9 | !@#",
                    prefixIcon: const Icon(Icons.lock),
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
              const SizedBox(height: 12),
              Text(
                " Nhập lại mật khẩu:",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                )
                ),
              const SizedBox(height: 12),
              /// CONFIRM PASSWORD
              Obx(() {
                return TextField(
                  controller: controllerRegis.confirmPasswordC,
                  obscureText: controllerRegis.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: "Nhập lại mật khẩu",
                    hintText: "Nhập lại mật khẩu",
                    prefixIcon: const Icon(Icons.lock_outlined),
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

              const SizedBox(height: 55),

              /// REGISTER BUTTON
              Obx(() {
                return SizedBox(
                  width: double.infinity,
                  height: 56,
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
                children: [
                  const Expanded(
                    child: Divider(
                      thickness: 1,
                      color: AppTheme.borderColor,
                    )
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "Hoặc đăng ký với",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: const Color.fromARGB(255, 56, 55, 55),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      thickness: 1,
                      color: AppTheme.borderColor,
                      )),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                      },
                      icon: Image.asset(
                        'assets/icon/google.png',
                        width: 40,
                      ),
                      label: 
                        Text(
                          "Google",
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                      },
                      icon: Icon(
                        Icons.phone,
                        size: 40,
                        color: Colors.black,
                        ),
                      label: 
                        Text(
                          "Số điện thoại",
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
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
