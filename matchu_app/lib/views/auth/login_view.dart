import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Đăng nhập")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() => Column(
          children: [
            TextField(
              controller: c.emailC,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: c.passwordC,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Mật khẩu"),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: c.isLoadingLogin.value
                    ? null
                    : c.loginC,
                child: c.isLoadingLogin.value
                    ? const CircularProgressIndicator()
                    : const Text("Đăng nhập"),
              ),
            ),
          ],
        )),
      ),
    );
  }
}
