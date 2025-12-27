import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';

import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/models/chat_room_model.dart';

class ChatListController extends GetxController {
  final ChatService _service = ChatService();
  String get uid => _service.uid;

  final RxList<ChatRoomModel> rooms = <ChatRoomModel>[].obs;
  final RxList<ChatRoomModel> filteredRooms = <ChatRoomModel>[].obs;

  final RxString searchText = "".obs;
  final textController = TextEditingController();
  final focusNode = FocusNode();
  
  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();

    _sub = _service.listenChatRooms().listen((newRooms) {
      _mergeAndReorder(newRooms);

      /// 🔥 QUAN TRỌNG: init filteredRooms
      applySearch();
    });

    /// ⏱ debounce search
    debounce(
      searchText,
      (_) => applySearch(),
      time: const Duration(milliseconds: 250),
    );
  }

  void _mergeAndReorder(List<ChatRoomModel> incoming) {
    final filtered = incoming.where((r) => !r.isDeletedFor(uid)).toList();

    filtered.sort((a, b) {
      final ap = a.isPinned(uid);
      final bp = b.isPinned(uid);
      if (ap != bp) return ap ? -1 : 1;

      final at = a.lastMessageAt ?? DateTime(0);
      final bt = b.lastMessageAt ?? DateTime(0);
      return bt.compareTo(at);
    });

    rooms.assignAll(filtered);
  }

  /// 🔍 SEARCH LOGIC (FIX)
  void applySearch() {
    final q = searchText.value.trim().toLowerCase();

    if (q.isEmpty) {
      filteredRooms.assignAll(rooms);
      return;
    }

    final userCache = Get.find<ChatUserCacheController>();

    filteredRooms.assignAll(
      rooms.where((room) {
        final otherUid = room.participants.firstWhere((e) => e != uid);
        final user = userCache.getUser(otherUid);

        final name = (user?.fullname ?? "").toLowerCase();
        final nick = (user?.nickname ?? "").toLowerCase();
        final msg = room.lastMessage.toLowerCase();

        return name.contains(q) ||
            nick.contains(q) ||
            msg.contains(q);
      }),
    );
  }

  void clearSearch() {
    searchText.value = "";
    textController.clear();   
    filteredRooms.assignAll(rooms);
    focusNode.unfocus(); 
  }

  Future<void> pin(ChatRoomModel room) async {
    await _service.setPinned(room.id, !room.isPinned(uid));
  }

  Future<void> delete(ChatRoomModel room) async {
    await _service.hideRoom(room.id);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
