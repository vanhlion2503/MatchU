import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/models/feed/post_chat_share_message.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/services/security/identity_key_service.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';

abstract interface class PostChatShareRepository {
  Future<void> sendToRoom({
    required ChatRoomModel room,
    required PostChatShareMessage message,
  });
}

class FirebasePostChatShareRepository implements PostChatShareRepository {
  FirebasePostChatShareRepository({ChatService? chatService})
    : _chatService = chatService ?? ChatService();

  final ChatService _chatService;

  @override
  Future<void> sendToRoom({
    required ChatRoomModel room,
    required PostChatShareMessage message,
  }) async {
    // Retry once when another device rotates the room key concurrently.
    for (var attempt = 0; attempt < 2; attempt++) {
      final keyId = await _prepareRoomKey(room.id);
      try {
        await _chatService.sendMessage(
          roomId: room.id,
          text: message.encode(),
          type: PostChatShareMessage.messageType,
          keyId: keyId,
        );
        return;
      } on FirebaseFunctionsException catch (error) {
        if (attempt == 0 && error.code == 'failed-precondition') continue;
        rethrow;
      }
    }
  }

  Future<int> _prepareRoomKey(String roomId) async {
    await IdentityKeyService.generateIfNotExists();
    final roomSnapshot = await _chatService.getRoom(roomId);
    final data = roomSnapshot.data();
    if (data == null) throw StateError('Không tìm thấy cuộc trò chuyện.');

    final participants = List<String>.from(data['participants'] ?? const []);
    final rawKeyId = data['currentKeyId'];
    final keyId = rawKeyId is num ? rawKeyId.toInt() : 0;
    if (await SessionKeyService.hasLocalSessionKey(roomId, keyId: keyId)) {
      unawaited(
        SessionKeyService.ensureDistributedToAllDevices(
          roomId: roomId,
          participantUids: participants,
          keyId: keyId,
        ).catchError((e) {
          debugPrint('Post share key repair failed: $e');
        }),
      );
      return keyId;
    }

    if (!await PasscodeBackupService.isHistoryLocked()) {
      final restored = await PasscodeBackupService.restoreSessionKeyForRoom(
        roomId,
        keyId: keyId,
      );
      if (restored) return keyId;
    }

    if (await SessionKeyService.receiveSessionKey(
      roomId: roomId,
      keyId: keyId,
    )) {
      unawaited(
        SessionKeyService.clearCurrentDeviceKeyRequest(
          roomId: roomId,
          keyId: keyId,
        ),
      );
      return keyId;
    }

    final hasExistingKeys =
        keyId == 0
            ? await SessionKeyService.hasAnySessionKeys(roomId)
            : await SessionKeyService.hasAnySessionKeysForKeyId(roomId, keyId);
    if (!hasExistingKeys) {
      await SessionKeyService.createAndSendSessionKey(
        roomId: roomId,
        participantUids: participants,
        keyId: keyId,
      );
      return keyId;
    }

    try {
      await SessionKeyService.requestSessionKey(roomId: roomId, keyId: keyId);
      final received = await SessionKeyService.waitForLocalSessionKey(
        roomId,
        keyId: keyId,
        timeout: const Duration(seconds: 5),
      );
      if (received) return keyId;
    } catch (e) {
      debugPrint('Post share key request failed: $e');
    }

    final rotatedKeyId = await SessionKeyService.rotateSessionKey(
      roomId: roomId,
      participantUids: participants,
    );
    unawaited(
      SessionKeyService.clearCurrentDeviceKeyRequest(
        roomId: roomId,
        keyId: keyId,
      ),
    );
    return rotatedKeyId;
  }
}
