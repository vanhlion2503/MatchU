import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});


@override
Widget build(BuildContext context) {
  final c = Get.find<AuthController>();
  return Scaffold(
    appBar: AppBar(
      title: const Text('Home'),
    actions: [
      IconButton(
      icon: const Icon(Icons.logout),
      onPressed: c.logoutC,
    )
    ],
  ),
  body: const Center(child: Text('Đăng nhập thành công!')),
  );
}
}
