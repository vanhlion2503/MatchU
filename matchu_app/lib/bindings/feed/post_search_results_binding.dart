import 'package:get/get.dart';
import 'package:matchu_app/controllers/search/post_search_controller.dart';
import 'package:matchu_app/models/feed/post_search_route_args.dart';
import 'package:matchu_app/services/feed/post_search_repository.dart';

class PostSearchResultsBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = PostSearchRouteArgs.tryParse(Get.arguments);
    final query = arguments?.query ?? Get.parameters['query']?.trim() ?? '';

    Get.lazyPut<PostSearchRepository>(() => PostSearchRepository());
    Get.lazyPut<PostSearchController>(
      () => PostSearchController(
        initialQuery: query,
        repository: Get.find<PostSearchRepository>(),
      ),
    );
  }
}
