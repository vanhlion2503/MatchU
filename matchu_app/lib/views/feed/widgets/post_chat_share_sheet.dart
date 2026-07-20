import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/feed/post_chat_share_controller.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:matchu_app/views/chat/chat_widget/user_avatar.dart';

class PostChatShareSheet extends StatefulWidget {
  const PostChatShareSheet({super.key, required this.post});

  final PostModel post;

  static Future<void> show(BuildContext context, {required PostModel post}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostChatShareSheet(post: post),
    );
  }

  @override
  State<PostChatShareSheet> createState() => _PostChatShareSheetState();
}

class _PostChatShareSheetState extends State<PostChatShareSheet> {
  static const int _maxRecipients = 10;

  late final ChatListController _chatListController;
  late final ChatUserCacheController _userCache;
  late final PostChatShareController _shareController;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedRoomIds = <String>{};
  final Set<String> _sentRoomIds = <String>{};
  String _query = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<PresenceController>()) {
      Get.put(PresenceController());
    }
    if (!Get.isRegistered<ChatUserCacheController>()) {
      Get.put(ChatUserCacheController());
    }
    _chatListController =
        Get.isRegistered<ChatListController>()
            ? Get.find<ChatListController>()
            : Get.put(ChatListController());
    _userCache = Get.find<ChatUserCacheController>();
    _shareController =
        Get.isRegistered<PostChatShareController>()
            ? Get.find<PostChatShareController>()
            : Get.put(PostChatShareController());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 3.5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: SizedBox(
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          PostTranslationKeys.selectConversations.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.65),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip:
                                MaterialLocalizations.of(
                                  context,
                                ).closeButtonTooltip,
                            visualDensity: VisualDensity.compact,
                            onPressed:
                                _isSending
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _searchController,
                    enabled: !_isSending,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                      hintText: PostTranslationKeys.searchConversations.tr,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Iconsax.search_normal_1,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 44),
                      suffixIcon:
                          _query.isEmpty
                              ? null
                              : IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.85,
                          ),
                          width: 1.1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildRoomList()),
              _buildSendBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomList() {
    return Obx(() {
      _userCache.version.value;
      final rooms = _filteredRooms(_chatListController.rooms);
      if (_chatListController.isLoading.value && rooms.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (rooms.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              PostTranslationKeys.noConversations.tr,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
        itemCount: rooms.length,
        itemBuilder: (context, index) => _buildRoomTile(rooms[index]),
      );
    });
  }

  List<ChatRoomModel> _filteredRooms(Iterable<ChatRoomModel> source) {
    final normalizedQuery = _query.toLowerCase();
    return source
        .where((room) {
          final otherUid = _otherUid(room);
          if (otherUid.isEmpty) return false;
          unawaited(_userCache.loadIfNeeded(otherUid));
          if (normalizedQuery.isEmpty) return true;

          final user = _userCache.getUser(otherUid);
          return (user?.fullname.toLowerCase().contains(normalizedQuery) ??
                  false) ||
              (user?.nickname.toLowerCase().contains(normalizedQuery) ?? false);
        })
        .toList(growable: false);
  }

  Widget _buildRoomTile(ChatRoomModel room) {
    final theme = Theme.of(context);
    final otherUid = _otherUid(room);
    final user = _userCache.getUser(otherUid);
    final isSelected = _selectedRoomIds.contains(room.id);
    final wasSent = _sentRoomIds.contains(room.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        enabled: !_isSending && !wasSent,
        dense: true,
        minVerticalPadding: 8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => _toggleRoom(room.id),
        leading: UserAvatar(userId: otherUid, radius: 22),
        title: Text(
          user?.fullname.trim().isNotEmpty == true
              ? user!.fullname.trim()
              : user?.nickname.trim().isNotEmpty == true
              ? '@${user!.nickname.trim()}'
              : PostTranslationKeys.matchuUser.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle:
            wasSent
                ? Text(
                  PostTranslationKeys.sent.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
                : null,
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color:
                isSelected || wasSent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.9,
                    ),
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  isSelected || wasSent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.85,
                      ),
              width: isSelected || wasSent ? 1.5 : 1.1,
            ),
          ),
          child:
              isSelected || wasSent
                  ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _buildSendBar(BuildContext context) {
    final count = _selectedRoomIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: _isSending || count == 0 ? null : _sendSelected,
          icon:
              _isSending
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Iconsax.send_1, size: 19),
          label: Text(
            _isSending
                ? PostTranslationKeys.sending.tr
                : '${PostTranslationKeys.send.tr}${count > 0 ? ' ($count)' : ''}',
          ),
          style: FilledButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  String _otherUid(ChatRoomModel room) {
    return room.participants.firstWhere(
      (uid) => uid != _chatListController.uid,
      orElse: () => '',
    );
  }

  void _toggleRoom(String roomId) {
    if (_isSending || _sentRoomIds.contains(roomId)) return;
    setState(() {
      if (!_selectedRoomIds.remove(roomId) &&
          _selectedRoomIds.length < _maxRecipients) {
        _selectedRoomIds.add(roomId);
      }
    });
  }

  Future<void> _sendSelected() async {
    final selectedRooms = _chatListController.rooms
        .where((room) => _selectedRoomIds.contains(room.id))
        .toList(growable: false);
    if (selectedRooms.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSending = true);
    final result = await _shareController.shareToRooms(
      post: widget.post,
      rooms: selectedRooms,
    );
    if (!mounted) return;

    setState(() {
      _isSending = false;
      _sentRoomIds.addAll(result.sentRoomIds);
      _selectedRoomIds
        ..clear()
        ..addAll(result.failedRoomIds);
    });

    if (result.sentRoomIds.isNotEmpty) {
      Get.snackbar(
        PostTranslationKeys.notice.tr,
        PostTranslationKeys.sentToConversations.trParams(<String, String>{
          'count': '${result.sentRoomIds.length}',
        }),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
    if (result.hasFailures) {
      Get.snackbar(
        PostTranslationKeys.error.tr,
        PostTranslationKeys.sendSomeFailed.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    Navigator.of(context).pop();
  }
}
