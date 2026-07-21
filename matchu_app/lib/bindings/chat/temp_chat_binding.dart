import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_controller.dart';
import 'package:matchu_app/controllers/game/wordChain/word_chain_controller.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import 'package:matchu_app/repositories/chat/temp_chat_repository.dart';

class TempChatBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    if (arguments is! Map || arguments['roomId'] is! String) {
      throw ArgumentError('TempChat route requires a roomId');
    }
    final roomId = arguments['roomId'] as String;

    Get.lazyPut<TempChatRepository>(() => TempChatService(), tag: roomId);
    Get.lazyPut<TelepathyController>(
      () => TelepathyController(roomId, usesExternalRoomState: true),
      tag: roomId,
    );
    Get.lazyPut<WordChainController>(
      () => WordChainController(roomId, usesExternalRoomState: true),
      tag: roomId,
    );
    Get.lazyPut<TempChatController>(
      () => TempChatController(
        roomId,
        service: Get.find<TempChatRepository>(tag: roomId),
        telepathyController: Get.find<TelepathyController>(tag: roomId),
        wordChainController: Get.find<WordChainController>(tag: roomId),
      ),
      tag: roomId,
    );
  }
}
