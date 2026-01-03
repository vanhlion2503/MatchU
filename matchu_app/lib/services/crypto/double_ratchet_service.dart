import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:matchu_app/services/crypto/secure_session_store.dart';

class DoubleRatchetService {
  static final _hmac = Hmac.sha256();
  static final _aes = AesGcm.with256bits();

  static const int _maxSkip = 50; // chuẩn Signal (chống DoS)

  // ================== KEY DERIVATION ==================

  static Future<List<int>> _deriveMessageKey(List<int> chainKey) async {
    final mac = await _hmac.calculateMac(
      const [0x01],
      secretKey: SecretKey(chainKey),
    );
    return mac.bytes;
  }

  static Future<List<int>> _deriveNextChainKey(List<int> chainKey) async {
    final mac = await _hmac.calculateMac(
      const [0x02],
      secretKey: SecretKey(chainKey),
    );
    return mac.bytes;
  }

  // ================== ENCRYPT ==================

  static Future<Map<String, dynamic>> encrypt({
    required String remoteUid,
    required String plaintext,
  }) async {
    final session = await SecureSessionStore.get(remoteUid);
    if (session == null) {
      throw Exception("Session not found for $remoteUid");
    }

    final msgIndex = session.sendCount;

    final mkBytes = await _deriveMessageKey(session.sendingChainKey);
    final mk = SecretKey(mkBytes);
    final nonce = _aes.newNonce();

    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: mk,
      nonce: nonce,
    );

    // 🔁 Ratchet forward
    session.sendingChainKey =
        await _deriveNextChainKey(session.sendingChainKey);
    session.sendCount++;

    await SecureSessionStore.save(remoteUid, session);

    return {
      "ciphertext": base64Encode(secretBox.cipherText),
      "nonce": base64Encode(secretBox.nonce),
      "mac": base64Encode(secretBox.mac.bytes),
      "count": msgIndex,
    };
  }

  // ================== DECRYPT ==================

  static Future<String> decrypt({
    required String remoteUid,
    required Map<String, dynamic> payload,
  }) async {
    final session = await SecureSessionStore.get(remoteUid);
    if (session == null) {
      throw Exception("Session not found for $remoteUid");
    }

    final int msgIndex = payload["count"];

    // ❌ old / duplicate message
    if (msgIndex < session.recvCount) {
      throw Exception("Old message (already processed)");
    }

    // ❌ skip quá xa → drop
    final skip = msgIndex - session.recvCount;
    if (skip > _maxSkip) {
      throw Exception("Message skipped too far ($skip)");
    }

    // 🔁 skip chain keys
    while (session.recvCount < msgIndex) {
      session.receivingChainKey =
          await _deriveNextChainKey(session.receivingChainKey);
      session.recvCount++;
    }

    // 🔑 derive message key
    final mkBytes = await _deriveMessageKey(session.receivingChainKey);
    final mk = SecretKey(mkBytes);

    final secretBox = SecretBox(
      base64Decode(payload["ciphertext"]),
      nonce: base64Decode(payload["nonce"]),
      mac: Mac(base64Decode(payload["mac"])),
    );

    final clear = await _aes.decrypt(
      secretBox,
      secretKey: mk,
    );

    // 🔁 ratchet forward
    session.receivingChainKey =
        await _deriveNextChainKey(session.receivingChainKey);
    session.recvCount++;

    await SecureSessionStore.save(remoteUid, session);

    return utf8.decode(clear);
  }
}
