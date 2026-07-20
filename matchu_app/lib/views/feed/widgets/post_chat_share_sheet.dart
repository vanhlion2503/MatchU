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
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        PostTranslationKeys.selectConversations.tr,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed:
                          _isSending ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchController,
                  enabled: !_isSending,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: PostTranslationKeys.searchConversations.tr,
                    prefixIcon: const Icon(Iconsax.search_normal_1, size: 20),
                    suffixIcon:
                        _query.isEmpty
                            ? null
                            : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Iconsax.close_circle, size: 20),
                            ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
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
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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

    return ListTile(
      enabled: !_isSending && !wasSent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: () => _toggleRoom(room.id),
      leading: UserAvatar(userId: otherUid, radius: 24),
      title: Text(
        user?.fullname.trim().isNotEmpty == true
            ? user!.fullname.trim()
            : user?.nickname.trim().isNotEmpty == true
            ? '@${user!.nickname.trim()}'
            : PostTranslationKeys.matchuUser.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle:
          wasSent
              ? Text(
                PostTranslationKeys.sent.tr,
                style: TextStyle(color: theme.colorScheme.primary),
              )
              : null,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color:
              isSelected || wasSent
                  ? theme.colorScheme.primary
                  : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                isSelected || wasSent
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
            width: 1.5,
          ),
        ),
        child:
            isSelected || wasSent
                ? Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                )
                : null,
      ),
    );
  }

  Widget _buildSendBar(BuildContext context) {
    final theme = Theme.of(context);
    final count = _selectedRoomIds.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SizedBox(
        width: double.infinity,
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
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
