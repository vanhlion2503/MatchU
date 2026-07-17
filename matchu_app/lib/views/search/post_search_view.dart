import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/search/post_search_entry_controller.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class PostSearchView extends StatefulWidget {
  const PostSearchView({super.key});

  @override
  State<PostSearchView> createState() => _PostSearchViewState();
}

class _PostSearchViewState extends State<PostSearchView> {
  late final PostSearchEntryController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<PostSearchEntryController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        toolbarHeight: 58,
        backgroundColor: palette.headerBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 48,
        leading: Semantics(
          button: true,
          label: 'Quay lại',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: Get.back,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_back_ios_new, size: 20),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          'Tìm kiếm bài viết',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchInput(controller: controller, palette: palette),
            Divider(height: 1, color: palette.border),
            Expanded(
              child: Obx(() {
                final isShowingSuggestions = controller.isShowingSuggestions;
                final history = controller.history.toList(growable: false);
                final suggestions = controller.suggestions.toList(
                  growable: false,
                );
                final isLoadingSuggestions =
                    controller.isLoadingSuggestions.value;

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child:
                      isShowingSuggestions
                          ? _SuggestionList(
                            key: const ValueKey('suggestions'),
                            controller: controller,
                            suggestions: suggestions,
                            isLoading: isLoadingSuggestions,
                            palette: palette,
                          )
                          : _HistoryList(
                            key: const ValueKey('history'),
                            controller: controller,
                            history: history,
                            palette: palette,
                          ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.palette});

  final PostSearchEntryController controller;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: palette.headerBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => TextField(
                      controller: controller.searchTextController,
                      focusNode: controller.searchFocusNode,
                      textInputAction: TextInputAction.search,
                      maxLength: 120,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      onChanged: controller.onQueryChanged,
                      onSubmitted: (_) => controller.submit(),
                      decoration: InputDecoration(
                        hintText: 'Nhập nội dung hoặc #hashtag',
                        prefixIcon: const Icon(
                          Iconsax.search_normal_1,
                          size: 20,
                        ),
                        suffixIcon:
                            controller.query.value.isEmpty
                                ? null
                                : IconButton(
                                  tooltip: 'Xóa nội dung',
                                  onPressed: controller.clearQuery,
                                  icon: const Icon(Icons.close, size: 20),
                                ),
                        filled: true,
                        fillColor: palette.inputSurface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: controller.submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Tìm'),
                ),
              ],
            ),
            Obx(
              () =>
                  controller.validationMessage.value == null
                      ? const SizedBox.shrink()
                      : Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          controller.validationMessage.value!,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    super.key,
    required this.controller,
    required this.history,
    required this.palette,
  });

  final PostSearchEntryController controller;
  final List<String> history;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _EmptyState(
        icon: Iconsax.clock,
        title: 'Chưa có lịch sử tìm kiếm',
        description: 'Các từ khóa bạn đã tìm sẽ xuất hiện tại đây.',
        palette: palette,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Lịch sử tìm kiếm',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: controller.clearHistory,
                child: const Text('Xóa tất cả'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final item in history)
          ListTile(
            leading: Icon(Iconsax.clock, size: 20, color: palette.textTertiary),
            title: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary),
            ),
            trailing: IconButton(
              tooltip: 'Xóa khỏi lịch sử',
              onPressed: () => controller.removeHistory(item),
              icon: Icon(Icons.close, size: 19, color: palette.textTertiary),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () => controller.submit(item),
          ),
      ],
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.isLoading,
    required this.palette,
  });

  final PostSearchEntryController controller;
  final List<String> suggestions;
  final bool isLoading;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Gợi ý tìm kiếm',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child:
              suggestions.isEmpty
                  ? _EmptyState(
                    icon: Iconsax.search_normal_1,
                    title:
                        isLoading ? 'Đang tìm gợi ý phù hợp' : 'Chưa có gợi ý',
                    description:
                        'Bạn vẫn có thể nhấn Tìm với từ khóa hiện tại.',
                    palette: palette,
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return ListTile(
                        leading: Icon(
                          Iconsax.search_normal_1,
                          size: 20,
                          color: palette.textTertiary,
                        ),
                        title: Text(
                          suggestion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textPrimary),
                        ),
                        trailing: Icon(
                          Icons.north_west,
                          size: 18,
                          color: palette.textTertiary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () => controller.submit(suggestion),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String description;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: palette.textTertiary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
