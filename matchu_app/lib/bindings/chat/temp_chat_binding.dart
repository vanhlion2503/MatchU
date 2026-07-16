import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';

class TempChatBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    if (arguments is! Map || arguments['roomId'] is! String) {
      throw ArgumentError('TempChat route requires a roomId');
    }
    final roomId = arguments['roomId'] as String;

    Get.lazyPut<TempChatService>(() => TempChatService(), tag: roomId);
    Get.lazyPut<TempChatController>(
      () => TempChatController(
        roomId,
        service: Get.find<TempChatService>(tag: roomId),
      ),
      tag: roomId,
    );
  }
}
