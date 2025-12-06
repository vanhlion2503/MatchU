import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/widgets/custom_app_bar.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});


@override
Widget build(BuildContext context) {
  final c = Get.find<AuthController>();
  return Scaffold(
  appBar: const CustomAppBar(title: "Trang chủ"),
  body: const Center(child: Text('Đăng nhập thành công!')),
  );
}
}
