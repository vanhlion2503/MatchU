import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/services/security/message_crypto_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';

class ChatListController extends GetxController
    with WidgetsBindingObserver {

  final ChatService _service = ChatService();
  String get uid => _service.uid;

  final RxList<ChatRoomModel> rooms = <ChatRoomModel>[].obs;
  final RxList<ChatRoomModel> filteredRooms = <ChatRoomModel>[].obs;
  final RxMap<String, String> lastMessagePreviewCache = <String, String>{}.obs;
  final Map<String, _PreviewMeta> _previewMeta = {};
  final Map<String, StreamSubscription<void>> _sessionKeySubs = {};
 
  final RxString searchText = "".obs;

  final textController = TextEditingController();
  final focusNode = FocusNode();

  StreamSubscription<List<ChatRoomModel>>? _sub;
  final isLoading = true.obs;
  bool _hasFirstData = false;
  bool _hasAnimated = false;

  @override
  void onInit() {
    super.onInit();

    final presence = Get.put(PresenceController(), permanent: true);
    
    WidgetsBinding.instance.addObserver(this);
    _sub = _service.listenChatRooms().listen(
      (incoming) {
        _mergeAndReorder(incoming);
        _applySearch();
        _keepAliveVisibleUsers();

        if (!_hasFirstData) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!isClosed) {
              isLoading.value = false;
            }
          });
          _hasFirstData = true;
        }
      },
      onError: (e) {
        isLoading.value = false;
      },
    );


    debounce(
      searchText,
      (_) => _applySearch(),
      time: const Duration(milliseconds: 250),
    );
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
    final visibleRoomIds = <String>{};

    for (final room in visible) {
      final otherUid = room.participants.firstWhere((e) => e != uid);
      userCache.loadIfNeeded(otherUid);
      presence.listen(otherUid);
      visibleRoomIds.add(room.id);
      _ensureSessionKeyListener(room.id);
      _loadLastMessagePreview(room);
    }

    presence.unlistenExcept(aliveUids);
    _cleanupSessionKeyListeners(visibleRoomIds);

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
        final preview = lastMessagePreviewCache[room.id] ?? room.lastMessage;

        if (preview.toLowerCase().contains(q)) {
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

  Future<void> _loadLastMessagePreview(ChatRoomModel room) async {
    await _loadLastMessagePreviewInternal(room);
  }

  void _ensureSessionKeyListener(String roomId) {
    if (_sessionKeySubs.containsKey(roomId)) return;

    _sessionKeySubs[roomId] =
        SessionKeyService.onSessionKeyUpdated(roomId).listen((_) async {
      ChatRoomModel? room;
      for (final r in rooms) {
        if (r.id == roomId) {
          room = r;
          break;
        }
      }
      if (room == null) return;
      await _loadLastMessagePreviewInternal(room, force: true);
    });
  }

  void _cleanupSessionKeyListeners(Set<String> aliveRoomIds) {
    final toRemove = _sessionKeySubs.keys
        .where((roomId) => !aliveRoomIds.contains(roomId))
        .toList();

    for (final roomId in toRemove) {
      _sessionKeySubs[roomId]?.cancel();
      _sessionKeySubs.remove(roomId);
    }
  }

  Future<void> _loadLastMessagePreviewInternal(
    ChatRoomModel room, {
    bool force = false,
  }) async {
    final meta = _previewMeta[room.id];
    final isSame = meta?.matches(room) == true;

    if (!force &&
        isSame &&
        lastMessagePreviewCache.containsKey(room.id)) {
      return;
    }

    if (room.lastMessageCipher == null || room.lastMessageIv == null) {
      lastMessagePreviewCache[room.id] = room.lastMessage;
      _previewMeta[room.id] = _PreviewMeta.fromRoom(room);
      if (searchText.value.trim().isNotEmpty) {
        _applySearch();
      }
      return;
    }

    try {
      final text = await MessageCryptoService.decrypt(
        roomId: room.id,
        ciphertext: room.lastMessageCipher!,
        iv: room.lastMessageIv!,
        keyId: room.lastMessageKeyId,
      );
      lastMessagePreviewCache[room.id] = text;
    } catch (e) {
      lastMessagePreviewCache[room.id] = room.lastMessage;
    } finally {
      _previewMeta[room.id] = _PreviewMeta.fromRoom(room);
      if (searchText.value.trim().isNotEmpty) {
        _applySearch();
      }
    }
  }

  void clearPreviewCache() {
    lastMessagePreviewCache.clear();
    _previewMeta.clear();
  }

  Future<void> refreshLastMessagePreviews() async {
    lastMessagePreviewCache.clear();

    for (final room in rooms) {
      await _loadLastMessagePreview(room);
    }

    _applySearch();
  }

  // ====================================================
  // 🔥 CLEANUP FOR LOGOUT
  // ====================================================
  void cleanup() {
    _sub?.cancel();
    _sub = null;
    rooms.clear();
    filteredRooms.clear();
    lastMessagePreviewCache.clear();
    _previewMeta.clear();
    for (final sub in _sessionKeySubs.values) {
      sub.cancel();
    }
    _sessionKeySubs.clear();
  }

  Future<void> cleanupAsync() async {
    final futures = <Future<void>>[];

    final sub = _sub;
    _sub = null;
    if (sub != null) {
      futures.add(sub.cancel());
    }

    for (final sub in _sessionKeySubs.values) {
      futures.add(sub.cancel());
    }
    _sessionKeySubs.clear();

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    rooms.clear();
    filteredRooms.clear();
    lastMessagePreviewCache.clear();
    _previewMeta.clear();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    cleanup();
    textController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}

class _PreviewMeta {
  final String? lastMessageCipher;
  final String? lastMessageIv;
  final int lastMessageKeyId;
  final String lastMessage;

  const _PreviewMeta({
    required this.lastMessageCipher,
    required this.lastMessageIv,
    required this.lastMessageKeyId,
    required this.lastMessage,
  });

  factory _PreviewMeta.fromRoom(ChatRoomModel room) {
    return _PreviewMeta(
      lastMessageCipher: room.lastMessageCipher,
      lastMessageIv: room.lastMessageIv,
      lastMessageKeyId: room.lastMessageKeyId,
      lastMessage: room.lastMessage,
    );
  }

  bool matches(ChatRoomModel room) {
    return lastMessageCipher == room.lastMessageCipher &&
        lastMessageIv == room.lastMessageIv &&
        lastMessageKeyId == room.lastMessageKeyId &&
        lastMessage == room.lastMessage;
  }
}
