import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';

class ChatController extends GetxController{
  final String roomId;
  ChatController(this.roomId);
  
  final ChatService _service = ChatService();
  final uid = Get.find<AuthController>().user!.uid;

  final scrollController = ScrollController();
  final inputController = TextEditingController();
  final isTyping = false.obs;
  final otherTyping = false.obs;

  final replyingMessage = Rxn<Map<String, dynamic>>();
  StreamSubscription? _roomSub;

  String? tempRoomId;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    final roomSnap = await _service.getRoom(roomId);
    tempRoomId = roomSnap.data()?["fromTempRoom"];
    _listenRoom();
  }

  void _listenRoom() {
    _roomSub = _service.listenRoom(roomId).listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final typing = data["typing"] ?? {};

      // typing flag nếu sau này bạn thêm
      otherTyping.value = typing.values.any((v) => v == true);
    });
    
  }

  Stream listenMessages() {
    return _service.listenMessagesWithFallback(roomId, tempRoomId);
  }

  Future<void> sendMessage({String type = "text"}) async {
    final text = inputController.text.trim();
    if(text.isEmpty) return;

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
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void startReply(Map<String,dynamic> msg){
    replyingMessage.value = msg;
  }

  void cancelReply(){
    replyingMessage.value = null;
  }

  @override
  void onClose(){
    _roomSub?.cancel();
    scrollController.dispose();
    inputController.dispose();
    super.onClose();
  }
}