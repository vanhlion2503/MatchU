import 'dart:convert';

class SessionState {
  List<int> rootKey;
  List<int> sendingChainKey;
  List<int> receivingChainKey;
  int sendCount;
  int recvCount;

  SessionState({
    required this.rootKey,
    required this.sendingChainKey,
    required this.receivingChainKey,
    this.sendCount = 0,
    this.recvCount = 0,
  });

  Map<String, dynamic> toJson() => {
    "rk": base64Encode(rootKey),
    "ck_s": base64Encode(sendingChainKey),
    "ck_r": base64Encode(receivingChainKey),
    "ns": sendCount,
    "nr": recvCount,
  };

  static SessionState fromJson(Map<String, dynamic> json) {
    return SessionState(
      rootKey: base64Decode(json["rk"]),
      sendingChainKey: base64Decode(json["ck_s"]),
      receivingChainKey: base64Decode(json["ck_r"]),
      sendCount: json["ns"],
      recvCount: json["nr"],
    );
  }
}
