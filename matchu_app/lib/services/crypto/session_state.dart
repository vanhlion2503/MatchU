class SessionState {
  final List<int> rootKey;
  final List<int> sendingChainKey;
  final List<int> receivingChainKey;

  SessionState({
    required this.rootKey,
    required this.sendingChainKey,
    required this.receivingChainKey,
  });
}
