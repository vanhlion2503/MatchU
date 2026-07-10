import 'dart:math' as math;

import 'package:matchu_app/models/feed/post_model.dart';

abstract class EmbeddingService {
  List<double> vectorForPost(PostModel post);
}

class KeywordEmbeddingService implements EmbeddingService {
  KeywordEmbeddingService({this.dimensions = 64});

  final int dimensions;

  @override
  List<double> vectorForPost(PostModel post) {
    if (post.contentVector.isNotEmpty) {
      return post.contentVector;
    }

    final tokens = _extractTokens(post);
    if (tokens.isEmpty || dimensions <= 0) {
      return const <double>[];
    }

    final vector = List<double>.filled(dimensions, 0);
    for (final token in tokens) {
      final index = _stableHash(token) % dimensions;
      vector[index] += token.length <= 4 ? 0.75 : 1;
    }

    return _normalize(vector);
  }

  List<String> _extractTokens(PostModel post) {
    final source = '${post.content} ${post.tags.join(' ')}';
    final normalized = source.toLowerCase().replaceAll(
      RegExp("[\\.,;:!\\?\\(\\)\\[\\]\\{\\}\\\"'/\\\\|<>+=*_`~]+"),
      ' ',
    );

    return normalized
        .split(RegExp(r'\s+'))
        .map((item) => item.replaceAll('#', '').trim())
        .where((item) => item.length >= 2)
        .toList(growable: false);
  }

  int _stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  List<double> _normalize(List<double> vector) {
    final magnitude = math.sqrt(
      vector.fold<double>(0, (sum, value) => sum + (value * value)),
    );
    if (magnitude == 0) return const <double>[];
    return vector.map((value) => value / magnitude).toList(growable: false);
  }
}
