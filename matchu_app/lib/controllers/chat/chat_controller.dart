import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/crypto/double_ratchet_service.dart';
import 'package:matchu_app/services/crypto/secure_session_store.dart';
import 'package:matchu_app/views/chat/long_chat/chat_bottom_bar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';

import 'package:matchu_app/services/crypto/signal_key_service.dart';
import 'package:matchu_app/services/crypto/x3dh_service.dart';



class ChatController extends GetxController {
  final String roomId;
  ChatController(this.roomId);

  final RxDouble bottomBarHeight = 0.0.obs;
  bool _justSentMessage = false;
  // ================= SERVICES =================
  final ChatService _service = ChatService();
  final String uid = Get.find<AuthController>().user!.uid;

  // ================= SCROLL =================
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  // ================= INPUT =================
  final inputController = TextEditingController();

  // ================= STATE =================
  final otherUid = RxnString();

  final isTyping = false.obs;
  final otherTyping = false.obs;
  final showEmoji = false.obs;

  /// 👉 user có đang đọc lịch sử hay không
  final RxBool userScrolledUp = false.obs;

  /// 👉 hiển thị nút ⬇
  final RxBool showNewMessageBtn = false.obs;

  /// 👉 số lượng message hiện tại
  int lastMessageCount = 0;
  final RxInt otherUnread = 0.obs;
  
  /// 👉 Pagination state - lưu tất cả messages đã load
  final RxList<QueryDocumentSnapshot<Map<String, dynamic>>> allMessages = <QueryDocumentSnapshot<Map<String, dynamic>>>[].obs;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  DocumentSnapshot<Map<String, dynamic>>? _oldestDocument; // Tin nhắn cũ nhất đã load

  final replyingMessage = Rxn<Map<String, dynamic>>();
  final highlightedMessageId = RxnString();

  StreamSubscription? _roomSub;
  Timer? _typingTimer;
  String? tempRoomId;
  late final PresenceController _presence;
  String? _listeningUid;

  final Map<String, int> _messageIndexMap = {};

  final encryptionReady = false.obs;

  final Map<String, String> _decryptedCache = {};

  bool _processingMessages = false;

  // ================= INIT =================
  @override
  void onInit() {
    super.onInit();
    _presence = Get.find<PresenceController>();
    _initRoom();
    _listenScroll();
    ever<bool>(otherTyping, _onOtherTypingChanged);
    // Load messages ban đầu
    loadInitialMessages();
  }

  void _onOtherTypingChanged(bool isTyping) {
    if (!isTyping) return;
    if (userScrolledUp.value) return;
    if (!itemScrollController.isAttached) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Với reverse: true, index 0 là typing bubble ở đáy
      itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: 1.0, // Đáy màn hình
      );
    });
  }

  void updateBottomBarHeight() {
    final ctx = ChatBottomBar.bottomBarKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    bottomBarHeight.value = box.size.height;
  }

  // ================= INIT ROOM =================
  Future<void> _initRoom() async {
    final roomSnap = await _service.getRoom(roomId);
    final data = roomSnap.data();
    if (data == null) return;

    await _service.markAsRead(roomId);

    final participants = List<String>.from(data["participants"]);
    final uidOther = participants.firstWhere((e) => e != uid);

    otherUid.value = uidOther;
    _listeningUid = uidOther;

    // 1️⃣ INIT SIGNAL (CHỈ 1 LẦN)
    await SignalKeyService.initSignalForUser(uid);

    // 2️⃣ ENSURE SESSION (X3DH)
    await ensureSession(uidOther);

    // 3️⃣ MARK READY (CHỈ CHO UID HIỆN TẠI)
    await _service.markEncryptionReady(roomId);

    // 4️⃣ LISTEN ROOM
    _listenRoomTyping();

    // 5️⃣ PRESENCE + CACHE
    _presence.listen(uidOther);
    Get.find<ChatUserCacheController>().loadIfNeeded(uidOther);
  }


  Future<void> ensureSession(String otherUid) async {
    if (await SecureSessionStore.has(otherUid)) return;

    final remoteKeys =
        await SignalKeyService.fetchRemoteKeys(otherUid);

    final isInitiator = uid.compareTo(otherUid) < 0;

    await X3dhService.establishSession(
      remoteUid: otherUid,
      remote: remoteKeys,
      initiator: isInitiator,
    );

    await FirebaseFunctions.instance
      .httpsCallable("consumePreKey")
      .call({
        "targetUid": otherUid,
        "preKeyId": remoteKeys.oneTimePreKeyId,
      });
  }



  // ================= ROOM LISTENER =================
  void _listenRoomTyping() {
    _roomSub = _service.listenRoom(roomId).listen((snap) {
      if (!snap.exists) return;

      final data = snap.data()!;

      final ready = data["encryptionReady"];

      if (ready is Map) {
        encryptionReady.value =
            ready[uid] == true && ready[otherUid.value] == true;
      } else {
        encryptionReady.value = false;
      }
      
      final typing = data["typing"] ?? {};
      final unread = data["unread"] ?? {};

      otherUnread.value = unread[otherUid.value] ?? 0;

      final isOtherTyping = typing.entries.any(
        (e) => e.key != uid && e.value == true,
      );

      if (isOtherTyping) {
        otherTyping.value = true;
      } else {
        // ⏳ delay để tránh xung đột với message mới
        Future.delayed(const Duration(milliseconds: 180), () {
          otherTyping.value = false;
        });
      }

    });
  }

  // ================= MESSAGE STREAM =================
  // Stream chỉ để listen messages mới nhất (realtime)
  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessages() {
    return _service.listenMessagesWithFallback(
      roomId, 
      tempRoomId,
      limit: 20, // Chỉ lấy 20 tin mới nhất để detect tin mới
    );
  }
  
  // Load messages ban đầu
  Future<void> loadInitialMessages() async {
    try {
      final snapshot = await _service.listenMessagesWithFallback(
        roomId,
        tempRoomId,
        limit: 20,
      ).first;
      
      final docs = snapshot.docs;
      if (docs.isEmpty) {
        _hasMoreMessages = false;
        return;
      }
      
      allMessages.value = docs;
      _rebuildIndexMap();
      _oldestDocument = docs.last; // Tin cũ nhất
      lastMessageCount = docs.length;
      
      // Nếu load được ít hơn 20, không còn tin nào nữa
      if (docs.length < 20) {
        _hasMoreMessages = false;
      }
    } catch (e) {
      print('Error loading initial messages: $e');
    }
  }

  void _rebuildIndexMap() {
    _messageIndexMap.clear();
    for (int i = 0; i < allMessages.length; i++) {
      _messageIndexMap[allMessages[i].id] = i;
    }
  }

  // ================= AUTO SCROLL CORE =================

  /// 🔥 GỌI SAU MỖI LẦN SNAPSHOT ĐỔI (realtime messages)
  Future<void> onNewMessages(
    int newCount,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_processingMessages) return;
    _processingMessages = true;

    try {
      if (docs.isEmpty) return;

      bool hasChange = false;

      for (final snap in docs) {
        final id = snap.id;
        final index = _messageIndexMap[id];
        final data = snap.data();

        // ADD / UPDATE
        if (index == null) {
          allMessages.insert(0, snap);
          for (final key in _messageIndexMap.keys) {
            _messageIndexMap[key] = _messageIndexMap[key]! + 1;
          }
          _messageIndexMap[id] = 0;
          hasChange = true;
        } else if (!_mapEquals(allMessages[index].data(), data)) {
          allMessages[index] = snap;
          hasChange = true;
        }

        // 🔐 DECRYPT (1 LẦN DUY NHẤT)
        if (_decryptedCache.containsKey(id)) continue;

        if (!data.containsKey("ciphertext")) {
          _decryptedCache[id] = data["text"] ?? "";
          continue;
        }

        final senderId = data["senderId"];
        final remoteUid = senderId == uid ? otherUid.value : senderId;
        if (remoteUid == null) continue;

        try {
          _decryptedCache[id] = await DoubleRatchetService.decrypt(
            remoteUid: remoteUid,
            payload: {
              "ciphertext": data["ciphertext"],
              "nonce": data["nonce"],
              "mac": data["mac"],
              "count": data["count"],
            },
          );
        } catch (_) {
          _decryptedCache[id] = "⚠️ Không giải mã được";
        }
      }

      if (!hasChange) return;

      lastMessageCount = allMessages.length;
      update();
    } finally {
      _processingMessages = false;
    }
  }


  String decryptedTextOf(String messageId) {
    return _decryptedCache[messageId] ?? "…";
  }

  bool _mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] is Map && b[key] is Map) {
        if (!_mapEquals(a[key], b[key])) return false;
      } else if (a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }




  void _scrollToBottom(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!itemScrollController.isAttached) return;

      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 1.0, // Đáy màn hình (vì reverse: true)
      );
    });
  }


  // ================= SCROLL LISTENER =================
  void _listenScroll() {
    itemPositionsListener.itemPositions.addListener(() {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      // Với reverse: true, index 0 ở đáy màn hình
      final minIndex =
          positions.map((e) => e.index).reduce((a, b) => a < b ? a : b);

      // Ở đáy nếu index 0 hoặc 1 đang visible
      final atBottom = minIndex <= 1;

      userScrolledUp.value = !atBottom;

      if (atBottom) {
        showNewMessageBtn.value = false;
      }

      // Load more khi scroll đến đầu list (index cao - tin cũ nhất)
      if (!_isLoadingMore && _hasMoreMessages && _oldestDocument != null) {
        final maxIndex =
            positions.map((e) => e.index).reduce((a, b) => a > b ? a : b);
        
        // Khi scroll đến 90% của list hiện tại (gần đầu), load more
        final totalItems = allMessages.length + 1; // +1 cho typing
        if (maxIndex >= totalItems * 0.9) {
          // Gọi method trực tiếp để tránh lỗi lookup
          Future.microtask(() => loadMoreMessages());
        }
      }
    });
  }

  // ================= LOAD MORE MESSAGES =================
  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _oldestDocument == null) return;
    
    _isLoadingMore = true;
    
    try {
      // Lấy thêm 20 tin nhắn cũ hơn
      final snapshot = await _service.listenMessagesWithFallback(
        roomId,
        tempRoomId,
        limit: 20,
        startAfter: _oldestDocument,
      ).first;
      
      final newDocs = snapshot.docs;
      
      if (newDocs.isEmpty) {
        _hasMoreMessages = false;
        _isLoadingMore = false;
        return;
      }
      
      // Thêm vào cuối list (vì reverse: true, cuối list là tin cũ nhất)
      allMessages.addAll(newDocs);

      final startIndex = allMessages.length - newDocs.length;
      for (int i = 0; i < newDocs.length; i++) {
        _messageIndexMap[newDocs[i].id] = startIndex + i;
      }
      _oldestDocument = newDocs.last; // Cập nhật tin cũ nhất
      lastMessageCount = allMessages.length;
      
      // Nếu load được ít hơn 20, không còn tin nào nữa
      if (newDocs.length < 20) {
        _hasMoreMessages = false;
      }
    } catch (e) {
      print('Error loading more messages: $e');
    } finally {
      _isLoadingMore = false;
    }
  }
  
  // Getter để check loading state
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreMessages => _hasMoreMessages;

  // ================= SEND MESSAGE =================
  Future<void> sendMessage({String type = "text"}) async {
    if (!encryptionReady.value) {
      Get.snackbar(
        "Đang thiết lập bảo mật",
        "Vui lòng chờ một chút...",
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    final text = inputController.text.trim();
    if (text.isEmpty) return;
    _justSentMessage = true; 
    _typingTimer?.cancel();
    isTyping.value = false;
    await _service.setTyping(roomId: roomId, isTyping: false);

    final reply = replyingMessage.value;

    await _service.sendMessage(
      roomId: roomId,
      text: text,
      type: type,
      replyToId: reply?["id"],
      replyText: reply?["text"],
    );

    replyingMessage.value = null;
    inputController.clear();
  }

  // ================= TYPING =================
  void onTypingChanged(String text) {
    if (!isTyping.value) {
      isTyping.value = true;
      _service.setTyping(roomId: roomId, isTyping: true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      isTyping.value = false;
      _service.setTyping(roomId: roomId, isTyping: false);
    });
  }

  // ================= REPLY =================
  void startReply(Map<String, dynamic> msg) {
    replyingMessage.value = msg;
  }

  void cancelReply() {
    replyingMessage.value = null;
  }

  // ================= EMOJI =================
  void toggleEmoji() => showEmoji.toggle();
  void hideEmoji() => showEmoji.value = false;

  // ================= FAB ACTION =================
  void onTapScrollToBottom() {
    userScrolledUp.value = false;
    showNewMessageBtn.value = false;
    _scrollToBottom(0); // Index 0 là tin mới nhất ở đáy
  }

  // ================= SCROLL TO MESSAGE =================
  void scrollToMessage({
    required List<QueryDocumentSnapshot> docs,
    required String messageId,
  }) {
    final index = docs.indexWhere((e) => e.id == messageId);
    if (index == -1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!itemScrollController.isAttached) return;

      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );

      highlightedMessageId.value = messageId;

      Future.delayed(const Duration(milliseconds: 900), () {
        if (highlightedMessageId.value == messageId) {
          highlightedMessageId.value = null;
        }
      });
    });
  }

  void onReactMessage({
    required String messageId,
    required String reactionId,
  }) {
    _service.toggleReaction(
      roomId: roomId,
      messageId: messageId,
      reactionId: reactionId,
    );
  }



  // ================= CLEAN UP =================
  @override
  void onClose() {
    _typingTimer?.cancel();
    _roomSub?.cancel();
    inputController.dispose();
    _service.setTyping(roomId: roomId, isTyping: false);
    if (_listeningUid != null) {
      _presence.unlistenExcept({});
    }
    super.onClose();
  }
}
