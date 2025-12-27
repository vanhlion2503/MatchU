import 'dart:async';

import 'package:get/get.dart';

import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/models/chat_room_model.dart';

class ChatListController extends GetxController{

  final ChatService _service = ChatService();

  final RxList<ChatRoomModel> rooms = <ChatRoomModel>[].obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    
    _sub = _service.listenChatRooms().listen((newRooms) {
      _mergeAndReorder(newRooms);
    });
  }

  void _mergeAndReorder(List<ChatRoomModel> incoming) {
    for (final room in incoming) {
      final index = rooms.indexWhere((r) => r.id == room.id);

      if (index == -1) {
        rooms.insert(0, room);
      } else {
        final old = rooms[index];
        if (old.lastMessageAt != room.lastMessageAt) {
          rooms.removeAt(index);
          rooms.insert(0, room);
        } else {
          rooms[index] = room;
        }
      }
    }
  }


  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

}