import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_search_route_args.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/feed/post_search_history_repository.dart';
import 'package:matchu_app/services/feed/post_search_suggestion_repository.dart';

class PostSearchEntryController extends GetxController {
  PostSearchEntryController({
    required PostSearchHistoryRepository historyRepository,
    required PostSearchSuggestionRepository suggestionRepository,
  }) : _historyRepository = historyRepository,
       _suggestionRepository = suggestionRepository;

  static const int _suggestionLimit = 8;

  final PostSearchHistoryRepository _historyRepository;
  final PostSearchSuggestionRepository _suggestionRepository;

  final TextEditingController searchTextController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final RxList<String> history = <String>[].obs;
  final RxList<String> suggestions = <String>[].obs;
  final RxString query = ''.obs;
  final RxBool isLoadingSuggestions = false.obs;
  final RxnString validationMessage = RxnString();

  Worker? _suggestionWorker;
  int _suggestionRequestVersion = 0;

  bool get isShowingSuggestions => query.value.trim().isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    history.assignAll(_historyRepository.read());
    _suggestionWorker = debounce<String>(
      query,
      _loadRemoteSuggestions,
      time: const Duration(milliseconds: 180),
    );
  }

  void onQueryChanged(String value) {
    query.value = value;
    validationMessage.value = null;
    _setLocalSuggestions(value);
    if (!_canRequestRemoteSuggestions(value)) {
      _suggestionRequestVersion++;
      isLoadingSuggestions.value = false;
    }
  }

  Future<void> submit([String? selectedQuery]) async {
    final normalized = _cleanQuery(selectedQuery ?? searchTextController.text);
    if (normalized.isEmpty) {
      validationMessage.value = 'Vui lòng nhập từ khóa cần tìm.';
      searchFocusNode.requestFocus();
      return;
    }

    searchTextController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    query.value = normalized;
    history.assignAll(await _historyRepository.add(normalized));
    searchFocusNode.unfocus();

    await Get.toNamed(
      AppRouter.postSearchResults,
      arguments: PostSearchRouteArgs(query: normalized),
    );
  }

  Future<void> removeHistory(String item) async {
    history.assignAll(await _historyRepository.remove(item));
    _setLocalSuggestions(query.value);
  }

  Future<void> clearHistory() async {
    await _historyRepository.clear();
    history.clear();
    _setLocalSuggestions(query.value);
  }

  void clearQuery() {
    searchTextController.clear();
    onQueryChanged('');
    searchFocusNode.requestFocus();
  }

  void _setLocalSuggestions(String rawQuery) {
    final normalized = _cleanQuery(rawQuery).toLowerCase();
    if (normalized.isEmpty) {
      suggestions.clear();
      return;
    }
    final localHistory = history.where(
      (item) => item.toLowerCase().contains(normalized),
    );
    final cached = _suggestionRepository.peek(
      rawQuery,
      limit: _suggestionLimit,
    );
    suggestions.assignAll(_mergeSuggestions(localHistory, cached));
  }

  Future<void> _loadRemoteSuggestions(String rawQuery) async {
    final normalized = _cleanQuery(rawQuery);
    if (!_canRequestRemoteSuggestions(normalized)) return;

    final requestVersion = ++_suggestionRequestVersion;
    isLoadingSuggestions.value = true;
    try {
      final remote = await _suggestionRepository.suggest(
        normalized,
        limit: _suggestionLimit,
      );
      if (requestVersion != _suggestionRequestVersion) return;

      suggestions.assignAll(_mergeSuggestions(suggestions, remote));
    } catch (_) {
      // Local-history suggestions remain usable when the network is offline.
    } finally {
      if (requestVersion == _suggestionRequestVersion) {
        isLoadingSuggestions.value = false;
      }
    }
  }

  String _cleanQuery(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool _canRequestRemoteSuggestions(String rawQuery) {
    final terms = _cleanQuery(
      rawQuery,
    ).replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').split(' ');
    return terms.any((term) => term.length >= 4);
  }

  List<String> _mergeSuggestions(
    Iterable<String> primary,
    Iterable<String> secondary,
  ) {
    final combined = <String>[];
    final seen = <String>{};
    for (final item in [...primary, ...secondary]) {
      final key = item.toLowerCase();
      if (seen.add(key)) combined.add(item);
      if (combined.length == _suggestionLimit) break;
    }
    return combined;
  }

  @override
  void onClose() {
    _suggestionWorker?.dispose();
    searchTextController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }
}
