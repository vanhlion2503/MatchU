/// Returns true when [text] contains only emoji code points, joiners,
/// variation selectors and whitespace.
bool isEmojiOnlyText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  var hasEmojiBase = false;
  for (final rune in trimmed.runes) {
    if (_isEmojiBase(rune)) {
      hasEmojiBase = true;
      continue;
    }
    if (_isEmojiModifier(rune) || _isWhitespace(rune)) continue;
    return false;
  }
  return hasEmojiBase;
}

bool _isEmojiBase(int rune) {
  return (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x2300 && rune <= 0x23FF) ||
      (rune >= 0x2B00 && rune <= 0x2BFF) ||
      (rune >= 0x1F1E6 && rune <= 0x1F1FF) ||
      rune == 0x00A9 ||
      rune == 0x00AE ||
      rune == 0x3030 ||
      rune == 0x303D ||
      rune == 0x3297 ||
      rune == 0x3299;
}

bool _isEmojiModifier(int rune) {
  return rune == 0x200D ||
      rune == 0x20E3 ||
      rune == 0xFE0E ||
      rune == 0xFE0F ||
      (rune >= 0x1F3FB && rune <= 0x1F3FF) ||
      (rune >= 0xE0020 && rune <= 0xE007F);
}

bool _isWhitespace(int rune) {
  return rune == 0x20 || rune == 0x0A || rune == 0x0D || rune == 0x09;
}
