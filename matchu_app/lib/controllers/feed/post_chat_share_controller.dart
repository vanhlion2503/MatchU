import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_share_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/models/feed/post_chat_share_message.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/repositories/feed/post_chat_share_repository.dart';

class PostChatShareResult {
  const PostChatShareResult({
    required this.sentRoomIds,
    required this.failedRoomIds,
  });

  final Set<String> sentRoomIds;
  final Set<String> failedRoomIds;
  bool get hasFailures => failedRoomIds.isNotEmpty;
}

class PostChatShareController extends GetxController {
  PostChatShareController({
    PostChatShareRepository? repository,
    PostShareController? postShareController,
  }) : _repository = repository ?? FirebasePostChatShareRepository(),
       _postShareController =
           postShareController ?? Get.find<PostShareController>();

  final PostChatShareRepository _repository;
  final PostShareController _postShareController;
  final RxSet<String> sendingRoomIds = <String>{}.obs;

  Future<PostChatShareResult> shareToRooms({
    required PostModel post,
    required Iterable<ChatRoomModel> rooms,
  }) async {
    final message = PostChatShareMessage.fromPost(post);
    final sent = <String>{};
    final failed = <String>{};

    for (final room in rooms) {
      final roomId = room.id.trim();
      if (roomId.isEmpty || sendingRoomIds.contains(roomId)) continue;

      sendingRoomIds.add(roomId);
      try {
        await _repository.sendToRoom(room: room, message: message);
        sent.add(roomId);
      } catch (error, stackTrace) {
        debugPrint('Failed to share post to room $roomId: $error');
        debugPrintStack(stackTrace: stackTrace);
        failed.add(roomId);
      } finally {
        sendingRoomIds.remove(roomId);
      }
    }

    if (sent.isNotEmpty) {
      // Record sequentially so absolute counter responses cannot arrive out of
      // order, while keeping metrics latency outside the sending UI.
      unawaited(_recordSuccessfulShares(post, sent.length));
    }

    return PostChatShareResult(sentRoomIds: sent, failedRoomIds: failed);
  }

  Future<void> _recordSuccessfulShares(PostModel post, int count) async {
    for (var index = 0; index < count; index++) {
      await _postShareController.recordChatShare(post);
    }
  }
}
