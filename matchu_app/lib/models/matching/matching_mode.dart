enum MatchingMode {
  chat('chat'),
  video('video');

  const MatchingMode(this.value);

  final String value;

  static MatchingMode fromValue(Object? value) {
    return value == video.value ? video : chat;
  }
}
