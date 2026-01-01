import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/list_chat/shimmer/chat_item_shimmer.dart';

class ChatListShimmer extends StatelessWidget {
  const ChatListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => const ChatItemShimmer(),
    );
  }
}
