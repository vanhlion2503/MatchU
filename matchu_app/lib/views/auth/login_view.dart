import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';
import 'package:iconsax/iconsax.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late AuthController c;

  @override
  void initState(){
    super.initState();
    c = Get.find<AuthController>();
    c.emailC.clear();
    c.passwordC.clear();
    c.otpC.clear();
    c.birthdayC.clear();
    c.nicknameC.clear();
    c.fullnameC.clear();

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BackCircleButton(
                  offset: const Offset(-6, -8),
                  size: 44,
                  iconSize: 20,
                ),
                // ===== TITLE =====
                Center(
                  child: Text(
                    "Chào mừng trở lại !",
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                // ===== SUBTITLE =====
                Center(
                  child: Text(
                    "Vui lòng nhập thông tin để đăng nhập.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                        ),
                  ),
                ),

                const SizedBox(height: 25),
                Text(
                  " Email",
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                ),
                const SizedBox(height: 12),
              /// EMAIL
                TextField(
                  controller: c.emailC,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    hintText: "abc@xyz.com",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                    " Mật khẩu",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                    ),
                    GestureDetector(
                      onTap: () {
                        Get.toNamed('/forgot-password');
                      },
                      child: Text(
                        "Quên mật khẩu",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              /// PASSWORD
              Obx(() {
                return TextField(
                  controller: c.passwordC,
                  obscureText: c.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: "Mật khẩu",
                    hintText: "Nhập mật khẩu",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        c.isPasswordHidden.value
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed:
                          c.isPasswordHidden.toggle,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              Obx(() => SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: c.isLoadingLogin.value
                      ? null
                      : c.loginC,
                  child: c.isLoadingLogin.value
                      ? const CircularProgressIndicator()
                      : const Text("Đăng nhập"),
                ),
              )),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        )
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "Hoặc tiếp tục với",
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        )),
                    ],
                  );
                },
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
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppTheme.darkBorder 
                              : AppTheme.lightBorder,
                        ),
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
                        Iconsax.mobile,
                        size: 40,
                        color: Theme.of(context).iconTheme.color,
                        ),
                      label: 
                        Text(
                          "Số điện thoại",
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppTheme.darkBorder 
                              : AppTheme.lightBorder,
                        ),
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
                    "Chưa có tài khoản?",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(AppRouter.register);
                    },
                    child: Text(
                      "Đăng ký",
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
        )
        ),
    );
  }
}
