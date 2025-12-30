import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/views/chat/long_chat/chat_bottom_bar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/services/chat/chat_service.dart';

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

  // ================= INIT =================
  @override
  void onInit() {
    super.onInit();
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
    otherUid.value = participants.firstWhere((e) => e != uid);

    tempRoomId = data["fromTempRoom"];

    Get.find<ChatUserCacheController>()
        .loadIfNeeded(otherUid.value!);

    _listenRoomTyping();
  }

  // ================= ROOM LISTENER =================
  void _listenRoomTyping() {
    _roomSub = _service.listenRoom(roomId).listen((snap) {
      if (!snap.exists) return;

      final data = snap.data()!;
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

  // ================= AUTO SCROLL CORE =================

  /// 🔥 GỌI SAU MỖI LẦN SNAPSHOT ĐỔI (realtime messages)
  void onNewMessages(int newCount, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return;
    
    final oldCount = allMessages.length;
    
    // Merge messages mới vào list (tránh duplicate)
    final existingIds = allMessages.map((e) => e.id).toSet();
    final newDocs = docs.where((doc) => !existingIds.contains(doc.id)).toList();
    
    if (newDocs.isNotEmpty) {
      // Thêm messages mới vào đầu list (vì reverse: true, index 0 là mới nhất)
      allMessages.insertAll(0, newDocs);
      lastMessageCount = allMessages.length;
    }
    
    final isNewMessage = newDocs.isNotEmpty;

    if (!userScrolledUp.value) {
      _service.markAsRead(roomId);
    }

    // ❌ KHÔNG auto-scroll khi vào phòng lần đầu
    if (oldCount == 0) {
      return;
    }

    // ✅ Chỉ scroll khi user vừa gửi tin
    if (_justSentMessage) {
      _justSentMessage = false;
      Future.microtask(() {
        _scrollToBottom(0); // Index 0 là tin mới nhất ở đáy
      });
      return;
    }

    // ✅ Chỉ scroll khi có tin nhắn mới realtime VÀ user đang ở đáy
    if (isNewMessage && !userScrolledUp.value) {
      _scrollToBottom(0); // Index 0 là tin mới nhất ở đáy
      return;
    }

    // User đang đọc lịch sử → hiển thị nút scroll
    if (isNewMessage && userScrolledUp.value) {
      showNewMessageBtn.value = true;
    }
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

  // ================= CLEAN UP =================
  @override
  void onClose() {
    _typingTimer?.cancel();
    _roomSub?.cancel();
    inputController.dispose();
    _service.setTyping(roomId: roomId, isTyping: false);
    super.onClose();
  }
}
