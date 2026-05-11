import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchu_app/services/security/identity_key_service.dart';
import 'package:matchu_app/services/security/message_crypto_service.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/views/chat/long_chat/chat_bottom_bar.dart';
import 'package:matchu_app/views/chat/long_chat/view_once_image_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';

class ChatController extends GetxController {
  final String roomId;
  ChatController(
    this.roomId, {
    String? initialMessageId,
    String? initialOtherUid,
  }) : _pendingFocusMessageId = _normalizeMessageId(initialMessageId),
       otherUid = RxnString(_normalizeUserId(initialOtherUid));

  final RxDouble bottomBarHeight = 0.0.obs;
  bool _justSentMessage = false;
  // ================= SERVICES =================
  final ChatService _service = ChatService();
  final String uid = Get.find<AuthController>().user!.uid;
  static const int _pageSize = 20;

  // ================= SCROLL =================
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  // ================= INPUT =================
  final inputController = TextEditingController();
  final inputFocusNode = FocusNode();

  final RxList<PendingImageMessage> pendingImageMessages =
      <PendingImageMessage>[].obs;
  final ImagePicker _picker = ImagePicker();

  // ================= STATE =================
  final RxnString otherUid;

  final isTyping = false.obs;
  final otherTyping = false.obs;
  final showEmoji = false.obs;

  /// 👉 user có đang đọc lịch sử hay không
  final RxBool userScrolledUp = false.obs;

  /// 👉 hiển thị nút ⬇
  final RxBool showNewMessageBtn = false.obs;

  /// 👉 số lượng message hiện tại
  int lastMessageCount = 0;
  final RxInt otherUnread = 0.obs;

  /// 👉 Pagination state - lưu tất cả messages đã load
  final RxList<QueryDocumentSnapshot<Map<String, dynamic>>> allMessages =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[].obs;
  final Rxn<Stream<QuerySnapshot<Map<String, dynamic>>>> messagesStream =
      Rxn<Stream<QuerySnapshot<Map<String, dynamic>>>>();
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _initialLoadComplete = false;
  String? _messageSourceRoot;
  DocumentSnapshot<Map<String, dynamic>>?
  _oldestDocument; // Tin nhắn cũ nhất đã load

  String? _pendingFocusMessageId;
  bool _isResolvingPendingFocus = false;

  final replyingMessage = Rxn<Map<String, dynamic>>();
  final editingMessage = Rxn<Map<String, dynamic>>();
  final highlightedMessageId = RxnString();
  final RxSet<String> deletedMessageIds = <String>{}.obs;

  StreamSubscription? _roomSub;
  Timer? _typingTimer;
  String? tempRoomId;
  late final PresenceController _presence;

  final Map<String, int> _messageIndexMap = {};

  final RxMap<String, String> decryptedCache = <String, String>{}.obs;
  final Set<String> _decrypting = {};
  StreamSubscription? _sessionKeySub;
  StreamSubscription?
  _sessionKeyListenerSub; // Realtime listener cho session key
  int _currentKeyId = 0;
  bool _isEnsuringKey = false;
  List<String> _roomParticipants = const [];
  final Map<int, Future<bool>> _localSessionKeyChecks = {};
  final Map<String, Map<String, dynamic>> _pendingDecryptQueue = {};
  bool _decryptQueueScheduled = false;

  static const String _encryptedPlaceholder = "Tin nhan duoc ma hoa";
  static const String _deletedPlaceholder = "Tin nhan da bi xoa";
  static const String _decryptPendingPlaceholder = "🔐 Đang thiết lập mã hóa…";
  static const String _decryptFailedPlaceholder =
      "⚠️ Không thể giải mã tin nhắn";
  static const String _deletedType = "deleted";
  static const String viewOnceImageText = "Ảnh";
  static const String viewOnceDeletedText = "Ảnh đã bị xóa";

  static String? _normalizeMessageId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeUserId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void onInit() {
    super.onInit();

    _presence = Get.find<PresenceController>();
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().enterChatRoom(roomId);
    }

    _sessionKeySub = SessionKeyService.onSessionKeyUpdated(roomId).listen((_) {
      _retryPendingDecrypts();
    });

    ever<bool>(otherTyping, _onOtherTypingChanged);
    _listenScroll();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    await _initRoom();
    if (isClosed) return;

    unawaited(
      _ensureSessionKey().then((_) {
        if (!isClosed) {
          _retryPendingDecrypts();
        }
      }),
    );
    await loadInitialMessages();
  }

  void _onOtherTypingChanged(bool isTyping) {
    if (!isTyping) return;
    if (userScrolledUp.value) return;
    if (!itemScrollController.isAttached) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Với reverse: true, index 0 là typing bubble ở đáy
      itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: 1.0, // Đáy màn hình
      );
    });
  }

  void updateBottomBarHeight() {
    final ctx = ChatBottomBar.bottomBarKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    bottomBarHeight.value = box.size.height;
  }

  void _markAsRead() {
    unawaited(_service.markAsRead(roomId).catchError((_) {}));
  }

  // ================= INIT ROOM =================
  Future<void> _initRoom() async {
    final roomSnap = await _service.getRoom(roomId);
    final data = roomSnap.data();
    if (data == null) return;

    _markAsRead();

    final fromTempRoom = data["fromTempRoom"];
    if (fromTempRoom is String && fromTempRoom.isNotEmpty) {
      tempRoomId = fromTempRoom;
    }

    final participants = List<String>.from(data["participants"] ?? const []);
    _roomParticipants = participants;

    final roomKeyId = data["currentKeyId"];
    if (roomKeyId is int) {
      _currentKeyId = roomKeyId;
    }

    final uidOther = participants.firstWhere(
      (e) => e != uid,
      orElse: () => otherUid.value ?? "",
    );

    if (uidOther.isNotEmpty && otherUid.value != uidOther) {
      otherUid.value = uidOther;
    }
    // 🔥 LISTEN PRESENCE Ở ĐÂY (CHUẨN)
    if (uidOther.isNotEmpty) {
      _presence.listen(uidOther);

      unawaited(Get.find<ChatUserCacheController>().loadIfNeeded(uidOther));
    }

    _ensureMessagesStreamReady();

    _listenRoomTyping();
  }

  // ================= ROOM LISTENER =================
  void _listenRoomTyping() {
    _roomSub = _service.listenRoom(roomId).listen((snap) {
      if (!snap.exists) return;

      final data = snap.data()!;
      final roomKeyId = data["currentKeyId"];
      if (roomKeyId is int && roomKeyId != _currentKeyId) {
        _currentKeyId = roomKeyId;
        _localSessionKeyChecks.remove(roomKeyId);
        _ensureSessionKey();
      }
      final typing = data["typing"] ?? {};
      final unread = data["unread"] ?? {};

      otherUnread.value = unread[otherUid.value] ?? 0;

      final isOtherTyping = typing.entries.any(
        (e) => e.key != uid && e.value == true,
      );

      if (isOtherTyping) {
        otherTyping.value = true;
      } else {
        // ⏳ delay để tránh xung đột với message mới
        Future.delayed(const Duration(milliseconds: 180), () {
          otherTyping.value = false;
        });
      }
    });
  }

  // ================= MESSAGE STREAM =================
  // Stream chỉ để listen messages mới nhất (realtime)
  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessages() {
    return _service.listenMessagesWithFallback(
      roomId,
      tempRoomId,
      limit: _pageSize, // Chỉ lấy 20 tin mới nhất để detect tin mới
    );
  }

  // Load messages ban đầu
  void _ensureMessagesStreamReady() {
    if (messagesStream.value != null) return;

    messagesStream.value =
        _service
            .listenMessagesWithFallback(roomId, tempRoomId, limit: _pageSize)
            .asBroadcastStream();
  }

  Future<void> loadInitialMessages() async {
    if (_initialLoadComplete) return;
    try {
      _ensureMessagesStreamReady();
      final stream = messagesStream.value;
      if (stream == null) return;

      final snapshot = await stream.first;

      if (_initialLoadComplete) return;

      final docs = snapshot.docs;
      if (docs.isEmpty) {
        _hasMoreMessages = false;
        _initialLoadComplete = true;
        _schedulePendingFocusResolution();
        return;
      }

      _applySnapshotAsBaseline(docs, _resolveSourceRoot(docs.first));
    } catch (e) {
      debugPrint('Error loading initial messages: $e');
    }
  }

  void _rebuildIndexMap() {
    _messageIndexMap.clear();
    for (int i = 0; i < allMessages.length; i++) {
      _messageIndexMap[allMessages[i].id] = i;
    }
  }

  void _updateDeletedFlag(String messageId, Map<String, dynamic> data) {
    if (data["type"] == _deletedType) {
      deletedMessageIds.add(messageId);
    } else {
      deletedMessageIds.remove(messageId);
    }
  }

  void _prepareMessage(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    bool deferEncrypted = false,
  }) {
    final data = doc.data();
    _updateDeletedFlag(doc.id, data);

    final isEncrypted =
        data.containsKey("ciphertext") && data.containsKey("iv");
    if (deferEncrypted && isEncrypted) {
      _queueDecrypt(doc.id, data);
      return;
    }

    unawaited(getDecryptedText(doc.id, data));
  }

  void _queueDecrypt(String messageId, Map<String, dynamic> data) {
    if (decryptedCache.containsKey(messageId) ||
        _decrypting.contains(messageId)) {
      return;
    }

    _pendingDecryptQueue[messageId] = Map<String, dynamic>.from(data);
    if (_decryptQueueScheduled) return;

    _decryptQueueScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) {
        _pendingDecryptQueue.clear();
        _decryptQueueScheduled = false;
        return;
      }

      unawaited(_drainDecryptQueue());
    });
  }

  Future<void> _drainDecryptQueue() async {
    _decryptQueueScheduled = false;

    var processed = 0;
    while (_pendingDecryptQueue.isNotEmpty && !isClosed) {
      final messageId = _pendingDecryptQueue.keys.first;
      final data = _pendingDecryptQueue.remove(messageId);
      if (data == null) continue;

      await getDecryptedText(messageId, data);
      processed++;

      if (processed % 4 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 12));
      }
    }
  }

  String _resolveSourceRoot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final segments = doc.reference.path.split('/');
    return segments.isNotEmpty ? segments.first : "";
  }

  void _applySnapshotAsBaseline(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String sourceRoot,
  ) {
    _messageSourceRoot =
        sourceRoot.isNotEmpty ? sourceRoot : _messageSourceRoot;
    allMessages.value = docs;
    _rebuildIndexMap();

    for (final doc in docs) {
      _prepareMessage(doc, deferEncrypted: true);
    }
    _oldestDocument = docs.isNotEmpty ? docs.last : null;
    lastMessageCount = docs.length;
    _hasMoreMessages = docs.length >= _pageSize;
    _initialLoadComplete = true;
    _schedulePendingFocusResolution();
  }

  // ================= AUTO SCROLL CORE =================

  /// 🔥 GỌI SAU MỖI LẦN SNAPSHOT ĐỔI (realtime messages)
  void onNewMessages(
    int newCount,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return;

    final sourceRoot = _resolveSourceRoot(docs.first);

    if (!_initialLoadComplete) {
      _applySnapshotAsBaseline(docs, sourceRoot);
      return;
    }

    if (_messageSourceRoot != null &&
        sourceRoot.isNotEmpty &&
        sourceRoot != _messageSourceRoot) {
      _applySnapshotAsBaseline(docs, sourceRoot);
      return;
    }

    if (_messageSourceRoot == null && sourceRoot.isNotEmpty) {
      _messageSourceRoot = sourceRoot;
    }

    bool hasChange = false;
    bool hasInsertedNewMessage = false;
    bool newestInsertedFromMe = false;

    for (final snap in docs) {
      final id = snap.id;
      final data = snap.data();
      final index = _messageIndexMap[id];

      if (index == null) {
        // ===============================
        // 🆕 MESSAGE MỚI
        // ===============================
        if (!hasInsertedNewMessage) {
          newestInsertedFromMe = data["senderId"] == uid;
        }
        hasInsertedNewMessage = true;
        allMessages.insert(0, snap);

        // shift index map
        for (final key in _messageIndexMap.keys) {
          _messageIndexMap[key] = _messageIndexMap[key]! + 1;
        }

        _messageIndexMap[id] = 0;
        hasChange = true;

        // 🔐 PRELOAD DECRYPT (ASYNC – KHÔNG BLOCK UI)
        getDecryptedText(id, data);
        _updateDeletedFlag(id, data);
      } else {
        // ===============================
        // ♻️ UPDATE MESSAGE (reaction / edit)
        // ===============================
        final oldData = allMessages[index].data();
        final newData = data;

        if (!_mapEquals(oldData, newData)) {
          allMessages[index] = snap;
          hasChange = true;
          _updateDeletedFlag(id, newData);

          if (!newData.containsKey("ciphertext")) {
            final rawText = newData["text"];
            if (rawText is String) {
              decryptedCache[id] = rawText;
            }
          }

          // 🔥 CHỈ decrypt lại nếu ciphertext / iv đổi
          final oldCipher = oldData["ciphertext"];
          final newCipher = newData["ciphertext"];
          final oldIv = oldData["iv"];
          final newIv = newData["iv"];

          if (oldCipher != newCipher || oldIv != newIv) {
            // ❗ key rotate / message re-encrypted
            decryptedCache.remove(id);
            getDecryptedText(id, newData);
          }
        }
      }
    }

    if (!hasChange) return;

    lastMessageCount = allMessages.length;
    _schedulePendingFocusResolution();

    if (!hasInsertedNewMessage) {
      return;
    }

    if (!userScrolledUp.value) {
      _markAsRead();
    }

    // ===============================
    // 🧭 SCROLL LOGIC (GIỮ NGUYÊN)
    // ===============================
    if (_justSentMessage && newestInsertedFromMe) {
      _justSentMessage = false;
      _scrollToBottom(0);
    } else if (!newestInsertedFromMe && !userScrolledUp.value) {
      _scrollToBottom(0);
    } else if (userScrolledUp.value) {
      showNewMessageBtn.value = true;
    }
  }

  bool _mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] is Map && b[key] is Map) {
        if (!_mapEquals(a[key], b[key])) return false;
      } else if (a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  void _scrollToBottom(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!itemScrollController.isAttached) return;

      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 1.0, // Đáy màn hình (vì reverse: true)
      );
    });
  }

  // ================= SCROLL LISTENER =================
  void _listenScroll() {
    itemPositionsListener.itemPositions.addListener(() {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      // Với reverse: true, index 0 ở đáy màn hình
      final minIndex = positions
          .map((e) => e.index)
          .reduce((a, b) => a < b ? a : b);

      // Ở đáy nếu index 0 hoặc 1 đang visible
      final atBottom = minIndex <= 1;

      userScrolledUp.value = !atBottom;

      if (atBottom) {
        showNewMessageBtn.value = false;
      }

      // Load more khi scroll đến đầu list (index cao - tin cũ nhất)
      if (!_isLoadingMore && _hasMoreMessages && _oldestDocument != null) {
        final maxIndex = positions
            .map((e) => e.index)
            .reduce((a, b) => a > b ? a : b);

        // Khi scroll đến 90% của list hiện tại (gần đầu), load more
        final totalItems = allMessages.length + 1 + pendingImageMessages.length;
        if (maxIndex >= totalItems * 0.9) {
          // Gọi method trực tiếp để tránh lỗi lookup
          Future.microtask(() => loadMoreMessages());
        }
      }
    });
  }

  // ================= LOAD MORE MESSAGES =================
  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _oldestDocument == null) return;

    _isLoadingMore = true;

    try {
      // Lấy thêm 20 tin nhắn cũ hơn
      final snapshot =
          await _service
              .listenMessagesWithFallback(
                roomId,
                tempRoomId,
                limit: _pageSize,
                startAfter: _oldestDocument,
              )
              .first;

      final newDocs = snapshot.docs;

      if (newDocs.isEmpty) {
        _hasMoreMessages = false;
        _isLoadingMore = false;
        return;
      }

      // Thêm vào cuối list (vì reverse: true, cuối list là tin cũ nhất)
      allMessages.addAll(newDocs);

      for (final doc in newDocs) {
        _prepareMessage(doc, deferEncrypted: true);
      }

      final startIndex = allMessages.length - newDocs.length;
      for (int i = 0; i < newDocs.length; i++) {
        _messageIndexMap[newDocs[i].id] = startIndex + i;
      }
      _oldestDocument = newDocs.last; // Cập nhật tin cũ nhất
      lastMessageCount = allMessages.length;

      // Nếu load được ít hơn 20, không còn tin nào nữa
      if (newDocs.length < _pageSize) {
        _hasMoreMessages = false;
      }
      _schedulePendingFocusResolution();
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  // Getter để check loading state
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreMessages => _hasMoreMessages;

  // ================= SEND MESSAGE =================
  Future<void> sendMessage({String type = "text"}) async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    final editing = editingMessage.value;
    if (editing != null) {
      await _submitEdit(messageId: editing["id"] as String, newText: text);
      return;
    }

    _justSentMessage = true;
    _typingTimer?.cancel();
    isTyping.value = false;
    await _service.setTyping(roomId: roomId, isTyping: false);

    final reply = replyingMessage.value;

    var hasKey = await SessionKeyService.hasLocalSessionKey(
      roomId,
      keyId: _currentKeyId,
    );
    if (!hasKey) {
      await _ensureSessionKey(allowRotateIfUnrecoverable: true);
      hasKey = await SessionKeyService.hasLocalSessionKey(
        roomId,
        keyId: _currentKeyId,
      );
    }
    if (!hasKey) {
      Get.snackbar("🔐", "Đang thiết lập mã hóa, vui lòng đợi...");
      return;
    }

    await _service.sendMessage(
      roomId: roomId,
      text: text,
      type: type,
      replyToId: reply?["id"],
      replyText: reply?["text"],
      keyId: _currentKeyId,
    );

    replyingMessage.value = null;
    inputController.clear();
  }

  Future<void> pickAndSendImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    if (editingMessage.value != null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    _justSentMessage = true;
    _typingTimer?.cancel();
    isTyping.value = false;
    await _service.setTyping(roomId: roomId, isTyping: false);

    final reply = replyingMessage.value;
    final pending = PendingImageMessage(
      id: "local_${DateTime.now().microsecondsSinceEpoch}",
    );
    pendingImageMessages.insert(0, pending);

    try {
      await _service.sendImageMessage(
        roomId: roomId,
        file: File(picked.path),
        replyToId: reply?["id"],
        replyText: reply?["text"],
        onUploadProgress: (progress) {
          final safe = progress.clamp(0.0, 1.0);
          pending.progress.value = safe;
        },
      );
      if (pendingImageMessages.contains(pending)) {
        pendingImageMessages.remove(pending);
      }
      replyingMessage.value = null;
    } catch (e) {
      pending.failed.value = true;
      Get.snackbar("Loi", "Khong the gui anh.");
      Future.delayed(const Duration(seconds: 2), () {
        pendingImageMessages.remove(pending);
      });
    }
  }

  bool _isLatestMessage(String messageId) {
    final index = _messageIndexMap[messageId];
    return index == 0;
  }

  Map<String, dynamic> _buildRoomPreviewUpdate({
    required String ciphertext,
    required String iv,
    required int keyId,
    required String messageType,
  }) {
    return {
      "lastMessage":
          messageType == _deletedType
              ? _deletedPlaceholder
              : _encryptedPlaceholder,
      "lastMessageType":
          messageType == _deletedType ? _deletedType : "encrypted",
      "lastMessageCipher": ciphertext,
      "lastMessageIv": iv,
      "lastMessageKeyId": keyId,
      "lastSenderId": uid,
    };
  }

  Future<bool> _ensureEditableKey() async {
    var hasKey = await SessionKeyService.hasLocalSessionKey(
      roomId,
      keyId: _currentKeyId,
    );
    if (!hasKey) {
      await _ensureSessionKey(allowRotateIfUnrecoverable: true);
      hasKey = await SessionKeyService.hasLocalSessionKey(
        roomId,
        keyId: _currentKeyId,
      );
    }

    if (!hasKey) {
      Get.snackbar("Loi", "Dang thiet lap ma hoa, vui long thu lai.");
      return false;
    }
    return true;
  }

  Future<void> _submitEdit({
    required String messageId,
    required String newText,
  }) async {
    _typingTimer?.cancel();
    isTyping.value = false;
    await _service.setTyping(roomId: roomId, isTyping: false);

    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    if (!await _ensureEditableKey()) return;

    final encrypted = await MessageCryptoService.encrypt(
      roomId: roomId,
      plaintext: trimmed,
      keyId: _currentKeyId,
    );

    final messageUpdate = {
      "ciphertext": encrypted["ciphertext"],
      "iv": encrypted["iv"],
      "keyId": _currentKeyId,
      "type": "text",
      "editedAt": FieldValue.serverTimestamp(),
      "editedBy": uid,
    };

    final roomUpdate =
        _isLatestMessage(messageId)
            ? _buildRoomPreviewUpdate(
              ciphertext: encrypted["ciphertext"]!,
              iv: encrypted["iv"]!,
              keyId: _currentKeyId,
              messageType: "text",
            )
            : null;

    try {
      await _service.updateMessage(
        roomId: roomId,
        messageId: messageId,
        messageUpdate: messageUpdate,
        roomUpdate: roomUpdate,
      );
      decryptedCache[messageId] = trimmed;
      deletedMessageIds.remove(messageId);
      editingMessage.value = null;
      inputController.clear();
    } catch (e) {
      Get.snackbar("Loi", "Khong the cap nhat tin nhan.");
    }
  }

  Future<void> deleteMessage({required String messageId}) async {
    if (!await _ensureEditableKey()) return;

    final encrypted = await MessageCryptoService.encrypt(
      roomId: roomId,
      plaintext: _deletedPlaceholder,
      keyId: _currentKeyId,
    );

    final messageUpdate = {
      "ciphertext": encrypted["ciphertext"],
      "iv": encrypted["iv"],
      "keyId": _currentKeyId,
      "type": _deletedType,
      "deletedAt": FieldValue.serverTimestamp(),
      "deletedBy": uid,
    };

    final roomUpdate =
        _isLatestMessage(messageId)
            ? _buildRoomPreviewUpdate(
              ciphertext: encrypted["ciphertext"]!,
              iv: encrypted["iv"]!,
              keyId: _currentKeyId,
              messageType: _deletedType,
            )
            : null;

    try {
      await _service.updateMessage(
        roomId: roomId,
        messageId: messageId,
        messageUpdate: messageUpdate,
        roomUpdate: roomUpdate,
      );
      decryptedCache[messageId] = _deletedPlaceholder;
      deletedMessageIds.add(messageId);
      if (editingMessage.value?["id"] == messageId) {
        cancelEdit();
      }
    } catch (e) {
      Get.snackbar("Loi", "Khong the xoa tin nhan.");
    }
  }

  void openViewOnceImage({
    required String messageId,
    required String senderId,
    required String imagePath,
    required bool isLatest,
  }) {
    if (imagePath.isEmpty) {
      Get.snackbar("Loi", viewOnceDeletedText);
      return;
    }

    final canDelete = senderId != uid;

    Get.to(
      () => ViewOnceImageView(
        imagePath: imagePath,
        canDelete: canDelete,
        onViewed: canDelete ? () => _markViewOnceImageViewed(messageId) : null,
        onExit:
            canDelete
                ? () => _deleteViewedImage(
                  messageId: messageId,
                  senderId: senderId,
                  imagePath: imagePath,
                  isLatest: isLatest,
                )
                : null,
      ),
    );
  }

  Future<void> _markViewOnceImageViewed(String messageId) async {
    try {
      await _service.updateMessage(
        roomId: roomId,
        messageId: messageId,
        messageUpdate: {"viewedBy.$uid": FieldValue.serverTimestamp()},
      );
    } catch (_) {}
  }

  Future<void> _deleteViewedImage({
    required String messageId,
    required String senderId,
    required String imagePath,
    required bool isLatest,
  }) async {
    final messageUpdate = {
      "type": _deletedType,
      "text": viewOnceDeletedText,
      "imagePath": FieldValue.delete(),
      "imageDeleted": true,
      "deletedAt": FieldValue.serverTimestamp(),
      "deletedBy": uid,
    };

    final roomUpdate =
        isLatest
            ? {
              "lastMessage": viewOnceDeletedText,
              "lastMessageType": _deletedType,
              "lastMessageCipher": FieldValue.delete(),
              "lastMessageIv": FieldValue.delete(),
              "lastMessageKeyId": 0,
              "lastSenderId": senderId,
            }
            : null;

    try {
      await _service.updateMessage(
        roomId: roomId,
        messageId: messageId,
        messageUpdate: messageUpdate,
        roomUpdate: roomUpdate,
      );
    } catch (_) {}

    try {
      await FirebaseStorage.instance.ref(imagePath).delete();
    } catch (_) {}
  }

  // ================= TYPING =================
  void onTypingChanged(String text) {
    if (!isTyping.value) {
      isTyping.value = true;
      _service.setTyping(roomId: roomId, isTyping: true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      isTyping.value = false;
      _service.setTyping(roomId: roomId, isTyping: false);
    });
  }

  // ================= REPLY =================
  void startReply(Map<String, dynamic> msg) {
    replyingMessage.value = msg;
  }

  void cancelReply() {
    replyingMessage.value = null;
  }

  // ================= EDIT =================
  void startEdit({required String messageId, required String text}) {
    replyingMessage.value = null;
    editingMessage.value = {"id": messageId, "text": text};

    inputController.text = text;
    inputController.selection = TextSelection.collapsed(offset: text.length);

    showEmoji.value = false;
    if (inputFocusNode.canRequestFocus) {
      inputFocusNode.requestFocus();
    }
  }

  void cancelEdit() {
    editingMessage.value = null;
    inputController.clear();
  }

  // ================= EMOJI =================
  void toggleEmoji() => showEmoji.toggle();
  void hideEmoji() => showEmoji.value = false;

  // ================= FAB ACTION =================
  void onTapScrollToBottom() {
    userScrolledUp.value = false;
    showNewMessageBtn.value = false;
    _scrollToBottom(0); // Index 0 là tin mới nhất ở đáy
  }

  // ================= SCROLL TO MESSAGE =================
  void focusMessageFromNotification(String messageId) {
    final normalized = _normalizeMessageId(messageId);
    if (normalized == null) return;

    _pendingFocusMessageId = normalized;
    _schedulePendingFocusResolution();
  }

  void _schedulePendingFocusResolution() {
    if (_pendingFocusMessageId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      unawaited(_resolvePendingFocusMessage());
    });
  }

  Future<void> _resolvePendingFocusMessage() async {
    if (_isResolvingPendingFocus || !_initialLoadComplete) return;

    _isResolvingPendingFocus = true;
    try {
      var attempt = 0;
      while (!isClosed) {
        final targetMessageId = _pendingFocusMessageId;
        if (targetMessageId == null) return;

        final listIndex = _messageListIndexForMessage(targetMessageId);
        if (listIndex != null) {
          _pendingFocusMessageId = null;
          userScrolledUp.value = false;
          showNewMessageBtn.value = false;
          _scrollToListIndex(listIndex, messageId: targetMessageId);
          _markAsRead();
          return;
        }

        if (!_hasMoreMessages || _oldestDocument == null || attempt >= 12) {
          _pendingFocusMessageId = null;
          return;
        }

        attempt += 1;
        await loadMoreMessages();
        await Future.delayed(const Duration(milliseconds: 90));
      }
    } finally {
      _isResolvingPendingFocus = false;
    }
  }

  int? _messageListIndexForMessage(String messageId) {
    final messageIndex = _messageIndexMap[messageId];
    if (messageIndex == null) return null;
    return 1 + pendingImageMessages.length + messageIndex;
  }

  void _scrollToListIndex(int index, {String? messageId}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!itemScrollController.isAttached) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (isClosed) return;
          _scrollToListIndex(index, messageId: messageId);
        });
        return;
      }

      itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );

      if (messageId == null) return;

      highlightedMessageId.value = messageId;

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (isClosed) return;
        if (highlightedMessageId.value == messageId) {
          highlightedMessageId.value = null;
        }
      });
    });
  }

  void scrollToMessage({
    required List<QueryDocumentSnapshot> docs,
    required String messageId,
  }) {
    final listIndex =
        _messageListIndexForMessage(messageId) ??
        (() {
          final index = docs.indexWhere((e) => e.id == messageId);
          if (index == -1) return null;
          return 1 + pendingImageMessages.length + index;
        })();
    if (listIndex == null) return;

    _scrollToListIndex(listIndex, messageId: messageId);
  }

  void onReactMessage({required String messageId, required String reactionId}) {
    _service.toggleReaction(
      roomId: roomId,
      messageId: messageId,
      reactionId: reactionId,
    );
  }

  Future<bool> _hasLocalSessionKey(int keyId) {
    return _localSessionKeyChecks.putIfAbsent(
      keyId,
      () => SessionKeyService.hasLocalSessionKey(roomId, keyId: keyId),
    );
  }

  Future<void> getDecryptedText(
    String messageId,
    Map<String, dynamic> data,
  ) async {
    if (!data.containsKey("ciphertext") || !data.containsKey("iv")) {
      final rawText = data["text"];
      if (rawText is String) {
        decryptedCache[messageId] = rawText;
      }
      return;
    }

    if (decryptedCache.containsKey(messageId)) return;
    if (_decrypting.contains(messageId)) return;

    _decrypting.add(messageId);
    final keyId = data["keyId"] is int ? data["keyId"] as int : 0;

    try {
      final hasKey = await _hasLocalSessionKey(keyId);
      if (!hasKey) {
        decryptedCache[messageId] = _decryptPendingPlaceholder;
        return;
      }

      final ciphertext = data["ciphertext"];
      final iv = data["iv"];

      if (ciphertext == null || iv == null) {
        throw Exception("Missing encrypted fields");
      }

      final text = await MessageCryptoService.decrypt(
        roomId: roomId,
        ciphertext: ciphertext,
        iv: iv,
        keyId: keyId,
      );

      decryptedCache[messageId] = text;
    } catch (e) {
      debugPrint("❌ Decrypt failed [$messageId]: $e");
      // 🔍 Debug: Kiểm tra session key có tồn tại không
      final hasKey = await SessionKeyService.hasLocalSessionKey(
        roomId,
        keyId: keyId,
      );
      debugPrint("🔍 Session key exists: $hasKey");

      final fallbackText = data["text"];
      if (fallbackText is String && fallbackText.isNotEmpty) {
        decryptedCache[messageId] = fallbackText;
      } else {
        decryptedCache[messageId] = _decryptFailedPlaceholder;
      }
    } finally {
      _decrypting.remove(messageId);
    }
  }

  void _retryPendingDecrypts() {
    _localSessionKeyChecks.clear();

    for (final doc in allMessages) {
      final data = doc.data();
      if (!data.containsKey("ciphertext") || !data.containsKey("iv")) {
        continue;
      }

      final cached = decryptedCache[doc.id];
      if (cached != null &&
          cached != _decryptPendingPlaceholder &&
          cached != _decryptFailedPlaceholder) {
        continue;
      }

      decryptedCache.remove(doc.id);
      _queueDecrypt(doc.id, data);
    }
  }

  Future<void> _ensureSessionKey({
    bool allowRotateIfUnrecoverable = false,
  }) async {
    if (_isEnsuringKey) return;
    _isEnsuringKey = true;

    try {
      await IdentityKeyService.generateIfNotExists();

      var participants = _roomParticipants;
      if (participants.isEmpty) {
        final roomSnap = await _service.getRoom(roomId);
        final data = roomSnap.data();
        if (data == null) return;

        participants = List<String>.from(data["participants"] ?? []);
        _roomParticipants = participants;

        final roomKeyId = data["currentKeyId"];
        _currentKeyId = roomKeyId is int ? roomKeyId : 0;
      }

      if (await SessionKeyService.hasLocalSessionKey(
        roomId,
        keyId: _currentKeyId,
      )) {
        return;
      }

      final hasAnyKeys =
          _currentKeyId == 0
              ? await SessionKeyService.hasAnySessionKeys(roomId)
              : await SessionKeyService.hasAnySessionKeysForKeyId(
                roomId,
                _currentKeyId,
              );
      final hasKeyForCurrentDevice =
          hasAnyKeys
              ? await SessionKeyService.hasSessionKeyForCurrentDevice(
                roomId,
                keyId: _currentKeyId,
              )
              : false;

      final historyLocked = await PasscodeBackupService.isHistoryLocked();
      if (!historyLocked) {
        final restoredFromBackup =
            await PasscodeBackupService.restoreSessionKeyForRoom(
              roomId,
              keyId: _currentKeyId,
            );
        if (restoredFromBackup) {
          unawaited(
            SessionKeyService.ensureDistributedToAllDevices(
              roomId: roomId,
              participantUids: participants,
              keyId: _currentKeyId,
            ).catchError((e, st) {
              debugPrint("Background session key distribution failed: $e");
            }),
          );
          SessionKeyService.notifyUpdated(roomId);
          return;
        }
      } else if (hasAnyKeys && allowRotateIfUnrecoverable) {
        final newKeyId = await SessionKeyService.rotateSessionKey(
          roomId: roomId,
          participantUids: participants,
        );
        _currentKeyId = newKeyId;
        return;
      }

      final received = await SessionKeyService.receiveSessionKey(
        roomId: roomId,
        keyId: _currentKeyId,
      );
      if (received) {
        return;
      }

      if (hasAnyKeys) {
        if (allowRotateIfUnrecoverable && !hasKeyForCurrentDevice) {
          debugPrint(
            "Room $roomId has existing session keys but this device cannot recover them, rotating to a new key",
          );
          final newKeyId = await SessionKeyService.rotateSessionKey(
            roomId: roomId,
            participantUids: participants,
          );
          _currentKeyId = newKeyId;
          return;
        }

        debugPrint("Room has keys, listening for session key...");
        _sessionKeyListenerSub?.cancel();

        _sessionKeyListenerSub = await SessionKeyService.listenForSessionKey(
          roomId: roomId,
          keyId: _currentKeyId,
          onKeyReceived: (success) async {
            if (success) {
              debugPrint("Session key received from realtime listener");
              _sessionKeyListenerSub?.cancel();
              _sessionKeyListenerSub = null;
            }
          },
        );

        debugPrint("Waiting for another device to distribute key...");
        return;
      }

      await SessionKeyService.createAndSendSessionKey(
        roomId: roomId,
        participantUids: participants,
        keyId: _currentKeyId,
      );
    } catch (e, st) {
      debugPrint("Session key setup failed for room $roomId: $e");
      debugPrintStack(stackTrace: st);
    } finally {
      _localSessionKeyChecks.clear();
      _isEnsuringKey = false;
    }
  }

  // ================= CLEAN UP =================
  @override
  void onClose() {
    _typingTimer?.cancel();
    _roomSub?.cancel();
    inputController.dispose();
    inputFocusNode.dispose();
    unawaited(
      _service.setTyping(roomId: roomId, isTyping: false).catchError((_) {}),
    );
    _sessionKeySub?.cancel();
    _sessionKeyListenerSub?.cancel();
    _localSessionKeyChecks.clear();
    _pendingDecryptQueue.clear();
    decryptedCache.clear();
    _decrypting.clear();
    deletedMessageIds.clear();
    pendingImageMessages.clear();
    allMessages.clear();
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().restoreAfterChatClosed(roomId);
    }
    super.onClose();
  }
}

class PendingImageMessage {
  final String id;
  final RxDouble progress = 0.0.obs;
  final RxBool failed = false.obs;

  PendingImageMessage({required this.id});
}
