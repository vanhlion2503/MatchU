import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/services/chat/matching_service.dart';

class RandomChatView extends StatefulWidget {
  @override
  State<RandomChatView> createState() => _RandomChatViewState();
}

class _RandomChatViewState extends State<RandomChatView> {
  String selectedTarget = "random";
  final _matchingService = MatchingService();

  @override
  void initState() {
    super.initState();
    
    /// 🔥 RESET isMatching khi vào màn
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Get.find<AuthController>();
      final user = auth.user;
      if (user != null) {
        await _matchingService.forceUnlock(user.uid);
        print("🔓 RESET isMatching for ${user.uid}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Random Chat")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Chọn giới tính mong muốn",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _radio("Ngẫu nhiên", "random"),
              _radio("Nam", "male"),
              _radio("Nữ", "female"),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Get.toNamed(
                      '/matching',
                      arguments: {"targetGender": selectedTarget},
                    );
                  },
                  child: const Text("🔍 Bắt đầu tìm kiếm"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radio(String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: selectedTarget,
      onChanged: (v) => setState(() => selectedTarget = v!),
    );
  }
}
