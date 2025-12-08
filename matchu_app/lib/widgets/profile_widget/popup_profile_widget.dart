import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/profile/profile_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';


void showEditBioDialog(BuildContext context, ProfileController c) {
  final TextEditingController bioC = TextEditingController(text: c.bio);

  showDialog(
    context: context,
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 550, 
            minHeight: 200,  
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // TITLE
                Text(
                  "Chỉnh sửa mô tả",
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: 15),

                // TEXT FIELD
                TextField(
                  controller: bioC,
                  maxLength: 150,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "Nhập mô tả của bạn...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Hủy"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,   
                        foregroundColor: Colors.white,         
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        c.updateBio(bioC.text.trim());
                        Navigator.pop(context);
                      },
                      child: const Text("Lưu"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
