import 'package:cloud_functions/cloud_functions.dart';

class PostSearchSuggestionRepository {
  PostSearchSuggestionRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<List<String>> suggest(String rawQuery, {int limit = 8}) async {
    final query = rawQuery.trim();
    if (query.length < 2) return const [];

    final callable = _functions.httpsCallable('suggestPostSearches');
    final response = await callable.call<Map<String, dynamic>>({
      'query': query,
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(response.data);
    return (data['suggestions'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(limit)
        .toList(growable: false);
  }
}
