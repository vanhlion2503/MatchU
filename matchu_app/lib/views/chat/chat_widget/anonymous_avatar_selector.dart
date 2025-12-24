import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';

class AnonymousAvatarSelector extends StatelessWidget {
  const AnonymousAvatarSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AnonymousAvatarController>();
    final size = MediaQuery.of(context).size;

    final double itemSize = 200;
    final int crossAxisCount =
        (size.width / itemSize).floor().clamp(3, 6);

    return SizedBox(
      height: size.height * 0.7, // ✅ 90% chiều cao màn hình
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Chọn avatar ẩn danh",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: GridView.builder(
              itemCount: c.avatars.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (_, i) {
                final key = c.avatars[i];

                return Obx(() {
                  final selected = c.selectedAvatar.value == key;

                  return GestureDetector(
                    onTap: () async {
                      await c.selectAndSave(key);
                      Get.back();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundImage:
                            AssetImage("assets/anonymous/$key.png"),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }


}
