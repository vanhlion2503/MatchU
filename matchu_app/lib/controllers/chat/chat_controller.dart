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
  }

  void _onOtherTypingChanged(bool isTyping) {
    if (!isTyping) return;

    // ❌ user đang đọc lịch sử → KHÔNG auto scroll
    if (userScrolledUp.value) return;

    // ❌ list chưa attach
    if (!itemScrollController.isAttached) return;

    // ✅ scroll nhẹ xuống cuối (typing bubble nằm sau last message)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      itemScrollController.scrollTo(
        index: lastMessageCount, // 👈 typing bubble index
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: 0.9,
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
  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessages() {
    return _service.listenMessagesWithFallback(roomId, tempRoomId);
  }

  // ================= AUTO SCROLL CORE =================

  /// 🔥 GỌI SAU MỖI LẦN SNAPSHOT ĐỔI
  void onNewMessages(int newCount) {
    final oldCount = lastMessageCount;
    lastMessageCount = newCount;

    // lần đầu load
    if (oldCount == 0) {
      _jumpToBottom(newCount - 1);
      return;
    }
    if (_justSentMessage) {
      _justSentMessage = false;
      Future.microtask(() {
        _scrollToBottom(newCount - 1);
      });
      return;
    }
    // user đang đọc lịch sử → KHÔNG auto scroll
    if (userScrolledUp.value) {
      showNewMessageBtn.value = true;
      return;
    }

    // user đang ở đáy → auto scroll
    _scrollToBottom(newCount - 1);
  }

  void _scrollToBottom(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!itemScrollController.isAttached) return;

      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.8,
      );
    });
  }

  void _jumpToBottom(int index) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!itemScrollController.isAttached) return;

    itemScrollController.jumpTo(
      index: index,
      alignment: 0.8, // 👈 FIX
    );
  });
}


  // ================= SCROLL LISTENER =================
  void _listenScroll() {
    itemPositionsListener.itemPositions.addListener(() {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      final maxIndex =
          positions.map((e) => e.index).reduce((a, b) => a > b ? a : b);

      final atBottom = maxIndex >= lastMessageCount - 2;

      userScrolledUp.value = !atBottom;

      if (atBottom) {
        showNewMessageBtn.value = false;
      }
    });
  }

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
    _scrollToBottom(lastMessageCount - 1);
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
