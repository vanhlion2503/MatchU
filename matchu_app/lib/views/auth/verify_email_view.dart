import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';


class VerifyEmailView extends StatelessWidget {
const VerifyEmailView({super.key});


@override
Widget build(BuildContext context) {
final c = Get.find<AuthController>();


return Scaffold(
appBar: AppBar(title: const Text('Xác minh Email')),
body: Padding(
padding: const EdgeInsets.all(24),
child: Column(
children: [
const Icon(Icons.email, size: 80),
const SizedBox(height: 24),
const Text('Chúng tôi đã gửi link xác minh. Hãy mở email và xác nhận.'),
const SizedBox(height: 24),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: c.checkEmailVeriFied,
child: const Text('Tôi đã xác minh'),
),
),
],
),
),
);
}
}