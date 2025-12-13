import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RandomChatView extends StatefulWidget {
  @override
  State<RandomChatView> createState() => _RandomChatViewState();
}

class _RandomChatViewState extends State<RandomChatView> {
  String selectedTarget = "random";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Random Chat")),
      body: SafeArea(
        child: SingleChildScrollView(
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
                      print("➡️ CLICK START MATCHING");
                      Get.toNamed(
                        '/matching',
                        arguments: {"targetGender": selectedTarget},
                      );
                    },
                    child: const Text(
                      "🔍 Bắt đầu tìm kiếm",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
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
