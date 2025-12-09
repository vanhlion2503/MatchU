import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/routes/app_router.dart';

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
      appBar: AppBar(
        toolbarHeight: 80,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: Column(
          children: [
            Text(
              "Chào mừng trở lại!",
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "Vui lòng nhập thông tin để đăng nhập.",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
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
                    Text(
                      "Quên mật khẩu"
                    )
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
              SizedBox(
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
              ),
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
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
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
                        Icons.phone,
                        size: 40,
                        color: Theme.of(context).iconTheme.color,
                        ),
                      label: 
                        Text(
                          "Số điện thoại",
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
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
