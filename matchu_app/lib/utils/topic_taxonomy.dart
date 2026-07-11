class TopicTaxonomy {
  TopicTaxonomy._();

  static const Map<String, String> _aliases = <String, String>{
    'flutter-dev': 'flutter',
    'flutterdev': 'flutter',
    'dart': 'flutter',
    'firebase-dev': 'firebase',
    'trí-tuệ-nhân-tạo': 'ai',
    'tri-tue-nhan-tao': 'ai',
    'artificial-intelligence': 'ai',
    'lập-trình-flutter': 'flutter',
    'lap-trinh-flutter': 'flutter',
    'lập trình flutter': 'flutter',
  };

  /// Returns stable IDs used by storage, embedding and analytics.
  static List<String> normalizeAll(Iterable<String> values) {
    final result = <String>{};
    for (final value in values) {
      final normalized = _normalize(value);
      if (normalized.isNotEmpty) result.add(_aliases[normalized] ?? normalized);
    }
    return result.toList(growable: false);
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^#+'), '')
        .replaceAll(RegExp(r'[_\s]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }
}
