import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:matchu_app/services/chat/chat_service.dart';

class ChatListController extends GetxController{

  final ChatService _service = ChatService();

  Stream get rooms => _service.listenChatRooms();
}