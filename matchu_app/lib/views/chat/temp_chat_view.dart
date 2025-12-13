import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TempChatView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;
    final roomId = args["roomId"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Temp Chat"),
      ),
      body: Center(
        child: Text(
          "💬 Room ID:\n$roomId",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
