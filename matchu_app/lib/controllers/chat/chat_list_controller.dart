import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/feed/post_restrictions_controller.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/chat_mute_setting.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/repositories/chat/chat_preferences_repository.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';
import 'package:matchu_app/services/security/message_crypto_service.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';

class ChatListController extends GetxController with WidgetsBindingObserver {
  ChatListController({
    ChatService? service,
    ChatPreferencesRepository? preferencesRepository,
    PostRestrictionService? restrictionService,
  }) : _service = service ?? ChatService(),
       _preferencesRepository =
           preferencesRepository ?? ChatPreferencesRepository(),
       _restrictionService = restrictionService ?? PostRestrictionService();

  final ChatService _service;
  final ChatPreferencesRepository _preferencesRepository;
  final PostRestrictionService _restrictionService;
  String get uid => _service.uid;

  final RxList<ChatRoomModel> rooms = <ChatRoomModel>[].obs;
  final RxList<ChatRoomModel> filteredRooms = <ChatRoomModel>[].obs;
  final RxMap<String, String> lastMessagePreviewCache = <String, String>{}.obs;
  final RxMap<String, ChatMuteSetting> mutedUsers =
      <String, ChatMuteSetting>{}.obs;
  final RxSet<String> processingRoomIds = <String>{}.obs;
  final Map<String, _PreviewMeta> _previewMeta = {};
  final Map<String, StreamSubscription<void>> _sessionKeySubs = {};

  final RxString searchText = "".obs;

  final textController = TextEditingController();
  final focusNode = FocusNode();

  StreamSubscription<List<ChatRoomModel>>? _sub;
  final isLoading = true.obs;
  bool _hasFirstData = false;
  final Set<String> _blockedUserIds = <String>{};
  List<ChatRoomModel> _latestIncomingRooms = const <ChatRoomModel>[];
  StreamSubscription<Set<String>>? _blockedUserIdsSub;
  StreamSubscription<List<ChatMuteSetting>>? _mutedUsersSub;
  Timer? _muteExpiryTimer;
  // bool _hasAnimated = false;

  @override
  void onInit() {
    super.onInit();

    // final presence = Get.put(PresenceController(), permanent: true);

    WidgetsBinding.instance.addObserver(this);
    _subscribeBlockedUserIds();
    _subscribeMutedUsers();
    _sub = _service.listenChatRooms().listen(
      (incoming) {
        _latestIncomingRooms = incoming;
        _mergeAndReorder(incoming);
        _applySearch();
        _keepAliveVisibleUsers();

        if (!_hasFirstData) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!isClosed) {
              isLoading.value = false;
            }
          });
          _hasFirstData = true;
        }
      },
      onError: (e) {
        isLoading.value = false;
      },
    );

    debounce(
      searchText,
      (_) => _applySearch(),
      time: const Duration(milliseconds: 250),
    );
  }

  /// ========================
  /// APP LIFECYCLE
  /// ========================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadVisibleUsers();
      _keepAliveVisibleUsers();
      _applySearch();
    }
  }

  /// ========================
  /// CORE
  /// ========================
  void _mergeAndReorder(List<ChatRoomModel> incoming) {
    final userCache = Get.find<ChatUserCacheController>();
    final presence = Get.find<PresenceController>();

    final visible =
        incoming
            .where((r) => !r.isDeletedFor(uid))
            .where((r) => !_isRoomWithBlockedUser(r))
            .toList();

    final aliveUids = <String>{};
    final visibleRoomIds = <String>{};

    for (final room in visible) {
      final otherUid = _otherUidOf(room);
      if (otherUid.isEmpty) continue;
      aliveUids.add(otherUid);
      unawaited(userCache.loadIfNeeded(otherUid));
      presence.listen(otherUid);
      visibleRoomIds.add(room.id);
      _ensureSessionKeyListener(room.id);
      unawaited(_loadLastMessagePreview(room));
    }

    presence.unlistenExcept(aliveUids);
    _cleanupSessionKeyListeners(visibleRoomIds);

    visible.sort((a, b) {
      final ap = a.isPinned(uid);
      final bp = b.isPinned(uid);
      if (ap != bp) return ap ? -1 : 1;

      final at = a.lastMessageAt ?? DateTime(0);
      final bt = b.lastMessageAt ?? DateTime(0);
      return bt.compareTo(at);
    });

    rooms.assignAll(visible);
  }

  /// ========================
  /// KEEP CACHE ALIVE
  /// ========================
  void _keepAliveVisibleUsers() {
    final userCache = Get.find<ChatUserCacheController>();

    final aliveUids =
        rooms.map(_otherUidOf).where((uid) => uid.isNotEmpty).toSet();

    userCache.cleanupExcept(aliveUids);
  }

  void _reloadVisibleUsers() {
    final userCache = Get.find<ChatUserCacheController>();

    for (final room in rooms) {
      final otherUid = _otherUidOf(room);
      if (otherUid.isEmpty) continue;
      unawaited(userCache.loadIfNeeded(otherUid));
    }
  }

  /// ========================
  /// SEARCH
  /// ========================
  void _applySearch() {
    final q = searchText.value.trim().toLowerCase();

    if (q.isEmpty) {
      filteredRooms.assignAll(rooms);
      return;
    }

    final userCache = Get.find<ChatUserCacheController>();

    filteredRooms.assignAll(
      rooms.where((room) {
        final preview = lastMessagePreviewCache[room.id] ?? room.lastMessage;

        if (preview.toLowerCase().contains(q)) {
          return true;
        }

        final otherUid = _otherUidOf(room);
        if (otherUid.isEmpty) return false;

        final user = userCache.getUser(otherUid);
        if (user == null) {
          unawaited(userCache.loadIfNeeded(otherUid));
          return false;
        }

        final name = (user.fullname).toLowerCase();
        final nick = (user.nickname).toLowerCase();

        return name.contains(q) || nick.contains(q);
      }),
    );
  }

  /// ========================
  /// UI
  /// ========================
  void clearSearch() {
    searchText.value = "";
    textController.clear();
    filteredRooms.assignAll(rooms);
    focusNode.unfocus();
  }

  Future<void> _loadBlockedUserIds() async {
    try {
      final blockedUserIds = await _restrictionService.fetchBlockedUserIds();
      _blockedUserIds
        ..clear()
        ..addAll(blockedUserIds);
      _mergeAndReorder(_latestIncomingRooms);
      _applySearch();
    } catch (_) {}
  }

  void _subscribeBlockedUserIds() {
    _blockedUserIdsSub?.cancel();
    _blockedUserIdsSub = _restrictionService.watchBlockedUserIds().listen(
      (blockedUserIds) {
        _blockedUserIds
          ..clear()
          ..addAll(blockedUserIds);
        _mergeAndReorder(_latestIncomingRooms);
        _applySearch();
      },
      onError: (_) {
        unawaited(_loadBlockedUserIds());
      },
    );
  }

  void applyUserBlocked(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    _blockedUserIds.add(normalizedUserId);
    _mergeAndReorder(_latestIncomingRooms);
    _applySearch();
  }

  void applyUserUnblocked(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    _blockedUserIds.remove(normalizedUserId);
    _mergeAndReorder(_latestIncomingRooms);
    _applySearch();
  }

  bool _isRoomWithBlockedUser(ChatRoomModel room) {
    final otherUid = _otherUidOf(room);
    return otherUid.isNotEmpty && _blockedUserIds.contains(otherUid);
  }

  String _otherUidOf(ChatRoomModel room) {
    return room.participants.firstWhere((e) => e != uid, orElse: () => '');
  }

  /// ========================
  /// ACTIONS
  /// ========================
  Future<void> pin(ChatRoomModel room) async {
    await _service.setPinned(room.id, !room.isPinned(uid));
  }

  Future<void> toggleReadState(ChatRoomModel room) async {
    await _runRoomAction(room.id, () async {
      if (room.unreadCount(uid) > 0) {
        await _service.markAsRead(room.id);
      } else {
        await _service.markAsUnread(room.id);
      }
    });
  }

  bool isMuted(String userId) {
    final setting = mutedUsers[userId.trim()];
    return setting?.isActiveAt(DateTime.now()) == true;
  }

  Future<void> muteUser(String userId, {Duration? duration}) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    await _preferencesRepository.muteUser(normalizedUserId, duration: duration);
  }

  Future<void> unmuteUser(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    await _preferencesRepository.unmuteUser(normalizedUserId);
  }

  Future<void> delete(ChatRoomModel room) async {
    await _runRoomAction(room.id, () => _service.hideRoom(room.id));
  }

  Future<bool> block(ChatRoomModel room) async {
    final otherUid = _otherUidOf(room);
    if (otherUid.isEmpty || processingRoomIds.contains(room.id)) return false;

    processingRoomIds.add(room.id);
    try {
      final userCache = Get.find<ChatUserCacheController>();
      final targetUser =
          userCache.getUser(otherUid) ?? await userCache.loadIfNeeded(otherUid);
      if (targetUser == null) {
        throw StateError('Không tìm thấy người dùng để chặn.');
      }

      final restrictionsController =
          Get.isRegistered<PostRestrictionsController>()
              ? Get.find<PostRestrictionsController>()
              : Get.put(PostRestrictionsController());
      return await restrictionsController.blockUser(targetUser);
    } finally {
      processingRoomIds.remove(room.id);
    }
  }

  Future<void> _runRoomAction(
    String roomId,
    Future<void> Function() action,
  ) async {
    if (processingRoomIds.contains(roomId)) return;
    processingRoomIds.add(roomId);
    try {
      await action();
    } finally {
      processingRoomIds.remove(roomId);
    }
  }

  void _subscribeMutedUsers() {
    _mutedUsersSub?.cancel();
    _mutedUsersSub = _preferencesRepository.watchMutedUsers().listen((
      settings,
    ) {
      mutedUsers.assignAll({
        for (final setting in settings) setting.userId: setting,
      });
      _scheduleMuteExpiryRefresh();
    }, onError: (_) => mutedUsers.clear());
  }

  void _scheduleMuteExpiryRefresh() {
    _muteExpiryTimer?.cancel();
    final now = DateTime.now();
    final expiries =
        mutedUsers.values
            .map((setting) => setting.mutedUntil)
            .whereType<DateTime>()
            .where((expiry) => expiry.isAfter(now))
            .toList();
    if (expiries.isEmpty) return;

    expiries.sort();
    _muteExpiryTimer = Timer(expiries.first.difference(now), () {
      if (isClosed) return;
      // Refresh observers when the nearest timed mute expires.
      mutedUsers.refresh();
      _scheduleMuteExpiryRefresh();
    });
  }

  Future<void> _loadLastMessagePreview(ChatRoomModel room) async {
    await _loadLastMessagePreviewInternal(room);
  }

  void _ensureSessionKeyListener(String roomId) {
    if (_sessionKeySubs.containsKey(roomId)) return;

    _sessionKeySubs[roomId] = SessionKeyService.onSessionKeyUpdated(
      roomId,
    ).listen((_) async {
      ChatRoomModel? room;
      for (final r in rooms) {
        if (r.id == roomId) {
          room = r;
          break;
        }
      }
      if (room == null) return;
      await _loadLastMessagePreviewInternal(room, force: true);
    });
  }

  void _cleanupSessionKeyListeners(Set<String> aliveRoomIds) {
    final toRemove =
        _sessionKeySubs.keys
            .where((roomId) => !aliveRoomIds.contains(roomId))
            .toList();

    for (final roomId in toRemove) {
      _sessionKeySubs[roomId]?.cancel();
      _sessionKeySubs.remove(roomId);
    }
  }

  Future<void> _loadLastMessagePreviewInternal(
    ChatRoomModel room, {
    bool force = false,
  }) async {
    final meta = _previewMeta[room.id];
    final isSame = meta?.matches(room) == true;

    if (!force && isSame && lastMessagePreviewCache.containsKey(room.id)) {
      return;
    }

    if (room.lastMessageCipher == null || room.lastMessageIv == null) {
      lastMessagePreviewCache[room.id] =
          room.lastMessageType == 'post_share'
              ? PostTranslationKeys.sharedPost.tr
              : room.lastMessage;
      _previewMeta[room.id] = _PreviewMeta.fromRoom(room);
      if (searchText.value.trim().isNotEmpty) {
        _applySearch();
      }
      return;
    }

    try {
      final keyId = room.lastMessageKeyId;
      final hasLocalKey = await SessionKeyService.hasLocalSessionKey(
        room.id,
        keyId: keyId,
      );
      if (!hasLocalKey && !(await PasscodeBackupService.isHistoryLocked())) {
        await PasscodeBackupService.restoreSessionKeyForRoom(
          room.id,
          keyId: keyId,
        );
      }

      final text = await MessageCryptoService.decrypt(
        roomId: room.id,
        ciphertext: room.lastMessageCipher!,
        iv: room.lastMessageIv!,
        keyId: keyId,
      );
      lastMessagePreviewCache[room.id] =
          room.lastMessageType == 'post_share'
              ? PostTranslationKeys.sharedPost.tr
              : text;
    } catch (e) {
      lastMessagePreviewCache[room.id] = room.lastMessage;
    } finally {
      _previewMeta[room.id] = _PreviewMeta.fromRoom(room);
      if (searchText.value.trim().isNotEmpty) {
        _applySearch();
      }
    }
  }

  void clearPreviewCache() {
    lastMessagePreviewCache.clear();
    _previewMeta.clear();
  }

  Future<void> refreshLastMessagePreviews() async {
    lastMessagePreviewCache.clear();

    for (final room in rooms) {
      await _loadLastMessagePreview(room);
    }

    _applySearch();
  }

  // ====================================================
  // 🔥 CLEANUP FOR LOGOUT
  // ====================================================
  void cleanup() {
    _sub?.cancel();
    _sub = null;
    _blockedUserIdsSub?.cancel();
    _blockedUserIdsSub = null;
    _mutedUsersSub?.cancel();
    _mutedUsersSub = null;
    _muteExpiryTimer?.cancel();
    _muteExpiryTimer = null;
    rooms.clear();
    filteredRooms.clear();
    lastMessagePreviewCache.clear();
    _previewMeta.clear();
    mutedUsers.clear();
    processingRoomIds.clear();
    for (final sub in _sessionKeySubs.values) {
      sub.cancel();
    }
    _sessionKeySubs.clear();
  }

  Future<void> cleanupAsync() async {
    final futures = <Future<void>>[];

    final sub = _sub;
    _sub = null;
    if (sub != null) {
      futures.add(sub.cancel());
    }

    final blockedUserIdsSub = _blockedUserIdsSub;
    _blockedUserIdsSub = null;
    if (blockedUserIdsSub != null) {
      futures.add(blockedUserIdsSub.cancel());
    }

    final mutedUsersSub = _mutedUsersSub;
    _mutedUsersSub = null;
    if (mutedUsersSub != null) {
      futures.add(mutedUsersSub.cancel());
    }
    _muteExpiryTimer?.cancel();
    _muteExpiryTimer = null;

    for (final sub in _sessionKeySubs.values) {
      futures.add(sub.cancel());
    }
    _sessionKeySubs.clear();

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    rooms.clear();
    filteredRooms.clear();
    lastMessagePreviewCache.clear();
    _previewMeta.clear();
    mutedUsers.clear();
    processingRoomIds.clear();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    cleanup();
    textController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}

class _PreviewMeta {
  final String? lastMessageCipher;
  final String? lastMessageIv;
  final int lastMessageKeyId;
  final String lastMessage;

  const _PreviewMeta({
    required this.lastMessageCipher,
    required this.lastMessageIv,
    required this.lastMessageKeyId,
    required this.lastMessage,
  });

  factory _PreviewMeta.fromRoom(ChatRoomModel room) {
    return _PreviewMeta(
      lastMessageCipher: room.lastMessageCipher,
      lastMessageIv: room.lastMessageIv,
      lastMessageKeyId: room.lastMessageKeyId,
      lastMessage: room.lastMessage,
    );
  }

  bool matches(ChatRoomModel room) {
    return lastMessageCipher == room.lastMessageCipher &&
        lastMessageIv == room.lastMessageIv &&
        lastMessageKeyId == room.lastMessageKeyId &&
        lastMessage == room.lastMessage;
  }
}
