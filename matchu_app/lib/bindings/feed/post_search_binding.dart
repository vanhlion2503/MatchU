import 'package:get/get.dart';
import 'package:matchu_app/controllers/search/post_search_controller.dart';
import 'package:matchu_app/services/feed/post_search_repository.dart';

class PostSearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PostSearchRepository>(() => PostSearchRepository());
    Get.lazyPut<PostSearchController>(
      () => PostSearchController(repository: Get.find<PostSearchRepository>()),
    );
  }
}
