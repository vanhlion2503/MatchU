import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';

class MatchingView extends StatefulWidget {
  @override
  State<MatchingView> createState() => _MatchingViewState();
}

class _MatchingViewState extends State<MatchingView> {
  final controller = Get.find<MatchingController>();

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>;
    final targetGender = args["targetGender"] as String;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.startMatching(targetGender: targetGender);
    });
  }

  @override
  void dispose() {
    /// 🔥 QUAN TRỌNG: cleanup khi view bị huỷ
    controller.stopMatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đang tìm người chat"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await controller.stopMatching();
            Get.back();
          },
        ),
      ),
      body: Center(
        child: Obx(() {
          if (controller.isMatched.value) {
            return const Text("🎉 Đã match!");
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Đang tìm người phù hợp..."),
            ],
          );
        }),
      ),
    );
  }
}

