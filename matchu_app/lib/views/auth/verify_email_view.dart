import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';
import 'package:url_launcher/url_launcher.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});
  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {

  late AuthController c;
  @override
  void initState() {
    super.initState();
    c = Get.find<AuthController>();

    c.startEmailTimer();
  }
    String maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }

    final visibleStart = name.substring(0, 2);
    final visibleEnd = name.substring(name.length - 1);

    return '$visibleStart***$visibleEnd@$domain';
  }
  Future<void> openGmail() async {
    final Uri gmailWeb = Uri.parse("https://mail.google.com/");

    if (await canLaunchUrl(gmailWeb)) {
      await launchUrl(
        gmailWeb,
        mode: LaunchMode.externalApplication, // 👉 bắt buộc
      );
    } else {
      Get.snackbar("Lỗi", "Không mở được Gmail");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 56, // 👈 đủ chỗ cho nút tròn
        leading: Align(
          alignment: Alignment.centerLeft,
          child: BackCircleButton(
            offset: const Offset(10, 0),
            size: 44,
            iconSize: 20,
          ),
        ),
        title:
        Text('Xác minh Email',
        style: Theme.of(context).textTheme.headlineMedium!.copyWith(
          fontWeight: FontWeight.bold,
        ),
        )
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.email, size: 80),
                const SizedBox(height: 24),
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Chúng tôi đã gửi link xác minh đến ',
                        ),
                        TextSpan(
                          text: maskEmail(c.emailC.text.trim()),
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                        const TextSpan(
                          text: '. Hãy mở email và xác nhận.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: openGmail,
                    icon: Icon(
                      Icons.open_in_new,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    label: Text(
                      'Mở email',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,       
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: c.checkEmailVerified,
                    child: Text('Tôi đã xác minh',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Obx(() => TextButton(
                  onPressed: c.resendEmailSeconds.value == 0
                      ? c.resendVerifyEmail
                      : null,
                  child: Text(
                    c.resendEmailSeconds.value == 0
                        ? "Gửi lại email"
                        : "Gửi lại sau ${c.resendEmailSeconds.value}s",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
