import 'package:get/get.dart';
import 'package:matchu_app/controllers/search/post_search_entry_controller.dart';
import 'package:matchu_app/services/feed/post_search_history_repository.dart';
import 'package:matchu_app/services/feed/post_search_suggestion_repository.dart';

class PostSearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PostSearchHistoryRepository>(
      () => PostSearchHistoryRepository(),
    );
    Get.lazyPut<PostSearchSuggestionRepository>(
      () => PostSearchSuggestionRepository(),
    );
    Get.lazyPut<PostSearchEntryController>(
      () => PostSearchEntryController(
        historyRepository: Get.find<PostSearchHistoryRepository>(),
        suggestionRepository: Get.find<PostSearchSuggestionRepository>(),
      ),
    );
  }
}
