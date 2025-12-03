import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:get/get.dart';

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
          icon: const Icon(Icons.arrow_back_ios ),),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Tạo tài khoản",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "Nhập thông tin để bắt đầu hành trình.",
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 112, 112, 112),
                ),
              ),
            ],
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Obx((){
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                TextField(
                  controller: controllerRegis.emailC,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'Nhập email của bạn',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controllerRegis.passwordC,
                  obscureText: controllerRegis.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: "Mật khẩu",
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: 'Nhập mật khẩu',
                    suffixIcon: IconButton(
                    icon: Icon(
                      controllerRegis.isPasswordHidden.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      controllerRegis.isPasswordHidden.toggle();
                    },
                  ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controllerRegis.confirmPasswordC,
                  obscureText: controllerRegis.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: "Nhập lại mật khẩu",
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: 'Nhập lại mật khẩu',
                    suffixIcon: IconButton(
                    icon: Icon(
                      controllerRegis.isPasswordHidden.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      controllerRegis.isPasswordHidden.toggle();
                    },
                  ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controllerRegis.phoneC,
                  decoration: InputDecoration(
                    labelText: "Số điện thoại",
                    prefixIcon: Icon(Icons.phone),
                    hintText: 'Nhập số điện thoại',
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: controllerRegis.isLoadingRegister.value ? null : controllerRegis.register, 
                  child: controllerRegis.isLoadingLogin.value ?
                    const CircularProgressIndicator()
                    : const Text("Đăng ký"), 
                  )
              ],
            );
          }),


        )
        ),
    );
  }
}