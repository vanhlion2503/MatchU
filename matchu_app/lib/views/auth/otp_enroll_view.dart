import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';

class OtpEnrollView extends StatelessWidget {
const OtpEnrollView({super.key});


@override
Widget build(BuildContext context) {
final c = Get.find<AuthController>();


return Scaffold(
appBar: AppBar(title: const Text('Xác nhận OTP')),
body: Padding(
padding: const EdgeInsets.all(24),
child: Column(
children: [
TextField(
controller: c.otpC,
keyboardType: TextInputType.number,
decoration: const InputDecoration(labelText: 'Mã OTP'),
),
const SizedBox(height: 24),
Obx(() => SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: c.isLoadingRegister.value ? null : c.confirmEnrollOtp,
child: c.isLoadingRegister.value
? const CircularProgressIndicator()
: const Text('Xác nhận'),
),
)),
],
),
),
);
}
}