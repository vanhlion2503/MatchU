import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';

class EnrollPhoneView extends StatelessWidget {
const EnrollPhoneView({super.key});


@override
Widget build(BuildContext context) {
final c = Get.find<AuthController>();


return Scaffold(
appBar: AppBar(title: const Text('Nhập số điện thoại')),
body: Padding(
padding: const EdgeInsets.all(24),
child: Column(
children: [
TextField(
onChanged: (v) => c.fullPhoneNumber.value = v,
keyboardType: TextInputType.phone,
decoration: const InputDecoration(labelText: 'Số điện thoại (+84...)'),
),
const SizedBox(height: 24),
Obx(() => SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: c.isLoadingRegister.value ? null : c.sendEnrollOtp,
child: c.isLoadingRegister.value
? const CircularProgressIndicator()
: const Text('Gửi OTP'),
),
)),
],
),
),
);
}
}