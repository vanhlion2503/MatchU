import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:matchu_app/controllers/feed/post_restrictions_controller.dart';
import 'package:matchu_app/models/feed/hidden_post_author_model.dart';

class RestrictionListView extends StatefulWidget {
  const RestrictionListView({super.key});

  @override
  State<RestrictionListView> createState() => _RestrictionListViewState();
}

class _RestrictionListViewState extends State<RestrictionListView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PostRestrictionsController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh s\u00E1ch h\u1EA1n ch\u1EBF'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'B\u1ECB ch\u1EB7n'),
            Tab(text: '\u1EA8n b\u00E0i vi\u1EBFt'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BlockedListPlaceholder(theme: theme),
          _HiddenPostAuthorsTab(controller: controller),
        ],
      ),
    );
  }
}

class _BlockedListPlaceholder extends StatelessWidget {
  const _BlockedListPlaceholder({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.shield_cross,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Danh s\u00E1ch b\u1ECB ch\u1EB7n',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'T\u00EDnh n\u0103ng n\u00E0y s\u1EBD \u0111\u01B0\u1EE3c ph\u00E1t tri\u1EC3n sau.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HiddenPostAuthorsTab extends StatelessWidget {
  const _HiddenPostAuthorsTab({required this.controller});

  final PostRestrictionsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final status = controller.hiddenAuthorsStatus.value;
      final items = controller.hiddenPostAuthors.toList(growable: false);

      if (status == PostRestrictionsStatus.loading && items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (status == PostRestrictionsStatus.error && items.isEmpty) {
        return _RestrictionState(
          icon: Iconsax.warning_2,
          title: 'Kh\u00F4ng th\u1EC3 t\u1EA3i danh s\u00E1ch',
          message:
              controller.errorMessage.value ??
              'Vui l\u00F2ng th\u1EED l\u1EA1i sau.',
          actionLabel: 'Th\u1EED l\u1EA1i',
          onAction: controller.loadHiddenPostAuthors,
        );
      }

      if (items.isEmpty) {
        return _RestrictionState(
          icon: Iconsax.eye_slash,
          title: 'Ch\u01B0a \u1EA9n ai',
          message:
              'Nh\u1EEFng ng\u01B0\u1EDDi b\u1EA1n \u0111\u00E3 \u1EA9n b\u00E0i vi\u1EBFt s\u1EBD xu\u1EA5t hi\u1EC7n \u1EDF \u0111\u00E2y.',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadHiddenPostAuthors,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemBuilder: (context, index) {
            return _HiddenAuthorTile(
              item: items[index],
              isLoading: controller.isAuthorUnhiding(items[index].authorId),
              onUnhide: () => controller.unhideAuthor(items[index].authorId),
            );
          },
          separatorBuilder:
              (context, index) => Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.45),
              ),
          itemCount: items.length,
        ),
      );
    });
  }
}

class _HiddenAuthorTile extends StatelessWidget {
  const _HiddenAuthorTile({
    required this.item,
    required this.isLoading,
    required this.onUnhide,
  });

  final HiddenPostAuthorModel item;
  final bool isLoading;
  final VoidCallback onUnhide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = item.avatarUrl.trim();
    final handle = item.handle;
    final hiddenAt = item.hiddenAt;
    final hiddenAtLabel =
        hiddenAt == null ? null : DateFormat('dd/MM/yyyy').format(hiddenAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child:
                avatarUrl.isEmpty
                    ? Text(item.title.characters.first.toUpperCase())
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (handle.isNotEmpty) '@$handle',
                    if (hiddenAtLabel != null)
                      '\u0110\u00E3 \u1EA9n t\u1EEB $hiddenAtLabel',
                  ].join(' \u2022 '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: isLoading ? null : onUnhide,
            child:
                isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('B\u1ECF \u1EA9n'),
          ),
        ],
      ),
    );
  }
}

class _RestrictionState extends StatelessWidget {
  const _RestrictionState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
