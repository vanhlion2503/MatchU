import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_detail_controller.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';

class PostDetailBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments;
    if (args is! PostDetailRouteArgs) {
      throw ArgumentError(
        'PostDetailRouteArgs is required when opening post detail.',
      );
    }

    Get.lazyPut<PostDetailController>(() => PostDetailController(args: args));
  }
}
