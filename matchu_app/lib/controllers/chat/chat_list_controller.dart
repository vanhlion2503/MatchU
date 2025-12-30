import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/services/chat/chat_service.dart';

class ChatListController extends GetxController
    with WidgetsBindingObserver {

  final ChatService _service = ChatService();
  String get uid => _service.uid;

  final RxList<ChatRoomModel> rooms = <ChatRoomModel>[].obs;
  final RxList<ChatRoomModel> filteredRooms = <ChatRoomModel>[].obs;

  final RxString searchText = "".obs;

  final textController = TextEditingController();
  final focusNode = FocusNode();

  StreamSubscription<List<ChatRoomModel>>? _sub;

  @override
  void onInit() {
    super.onInit();

    final presence = Get.put(PresenceController(), permanent: true);
    
    WidgetsBinding.instance.addObserver(this);
    _sub = _service.listenChatRooms().listen((incoming) {
      _mergeAndReorder(incoming);
      _applySearch();
      _keepAliveVisibleUsers();
    });

    debounce(
      searchText,
      (_) => _applySearch(),
      time: const Duration(milliseconds: 250),
    );
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    textController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  /// ========================
  /// APP LIFECYCLE
  /// ========================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadVisibleUsers();
      _keepAliveVisibleUsers();
      _applySearch();
    }
  }

  /// ========================
  /// CORE
  /// ========================
  void _mergeAndReorder(List<ChatRoomModel> incoming) {
    final userCache = Get.find<ChatUserCacheController>();
    final presence = Get.find<PresenceController>();

    final visible = incoming
        .where((r) => !r.isDeletedFor(uid))
        .toList();

    final aliveUids = <String>{};

    for (final room in visible) {
      final otherUid =
          room.participants.firstWhere((e) => e != uid);
      userCache.loadIfNeeded(otherUid);
      presence.listen(otherUid);
      aliveUids.add(otherUid);
    }

    presence.unlistenExcept(aliveUids);

    visible.sort((a, b) {
      final ap = a.isPinned(uid);
      final bp = b.isPinned(uid);
      if (ap != bp) return ap ? -1 : 1;

      final at = a.lastMessageAt ?? DateTime(0);
      final bt = b.lastMessageAt ?? DateTime(0);
      return bt.compareTo(at);
    });

    rooms.assignAll(visible);
  }

  /// ========================
  /// KEEP CACHE ALIVE
  /// ========================
  void _keepAliveVisibleUsers() {
    final userCache = Get.find<ChatUserCacheController>();

    final aliveUids = rooms
        .map((r) => r.participants.firstWhere((e) => e != uid))
        .toSet();

    userCache.cleanupExcept(aliveUids);
  }

  void _reloadVisibleUsers() {
    final userCache = Get.find<ChatUserCacheController>();

    for (final room in rooms) {
      final otherUid =
          room.participants.firstWhere((e) => e != uid);
      userCache.loadIfNeeded(otherUid);
    }
  }

  /// ========================
  /// SEARCH
  /// ========================
  void _applySearch() {
    final q = searchText.value.trim().toLowerCase();

    if (q.isEmpty) {
      filteredRooms.assignAll(rooms);
      return;
    }

    final userCache = Get.find<ChatUserCacheController>();

    filteredRooms.assignAll(
      rooms.where((room) {
        if (room.lastMessage.toLowerCase().contains(q)) {
          return true;
        }

        final otherUid =
            room.participants.firstWhere((e) => e != uid);

        final user = userCache.getUser(otherUid);
        if (user == null) {
          userCache.loadIfNeeded(otherUid);
          return false;
        }

        final name = (user.fullname ?? "").toLowerCase();
        final nick = (user.nickname ?? "").toLowerCase();

        return name.contains(q) || nick.contains(q);
      }),
    );
  }

  /// ========================
  /// UI
  /// ========================
  void clearSearch() {
    searchText.value = "";
    textController.clear();
    filteredRooms.assignAll(rooms);
    focusNode.unfocus();
  }

  /// ========================
  /// ACTIONS
  /// ========================
  Future<void> pin(ChatRoomModel room) async {
    await _service.setPinned(room.id, !room.isPinned(uid));
  }

  Future<void> delete(ChatRoomModel room) async {
    await _service.hideRoom(room.id);
  }
}
