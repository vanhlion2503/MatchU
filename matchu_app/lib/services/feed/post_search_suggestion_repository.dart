import 'package:cloud_functions/cloud_functions.dart';

class PostSearchSuggestionRepository {
  PostSearchSuggestionRepository({FirebaseFunctions? functions})
    : _callable = (functions ?? FirebaseFunctions.instance).httpsCallable(
        'suggestPostSearches',
      );

  static const Duration _cacheTtl = Duration(minutes: 3);
  static const int _maxCacheEntries = 30;

  final HttpsCallable _callable;
  final Map<String, _SuggestionCacheEntry> _cache = {};
  final Map<String, Future<List<String>>> _inFlight = {};

  Future<List<String>> suggest(String rawQuery, {int limit = 8}) async {
    final query = _cleanQuery(rawQuery);
    if (query.length < 2) return const [];

    final key = _cacheKey(query, limit);
    final cached = _readCache(key);
    if (cached != null) return cached;

    // Reuse the same Future when the debounce fires twice for one query.
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final request = _fetch(query, limit);
    _inFlight[key] = request;
    try {
      final suggestions = await request;
      _writeCache(key, query, limit, suggestions);
      return suggestions;
    } finally {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  /// Returns a best-effort cached subset while a more specific query loads.
  /// This only affects perceived latency; the server result still replaces it.
  List<String> peek(String rawQuery, {int limit = 8}) {
    final query = _normalizeForComparison(rawQuery);
    if (query.isEmpty) return const [];

    _removeExpiredEntries();
    final entries = _cache.values.toList(growable: false).reversed;
    for (final entry in entries) {
      if (entry.limit != limit) continue;
      final cachedQuery = _normalizeForComparison(entry.query);
      if (!query.startsWith(cachedQuery)) continue;

      return entry.suggestions
          .where((item) => _normalizeForComparison(item).startsWith(query))
          .take(limit)
          .toList(growable: false);
    }
    return const [];
  }

  Future<List<String>> _fetch(String query, int limit) async {
    final response = await _callable.call<Map<String, dynamic>>({
      'query': query,
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(response.data);
    return List<String>.unmodifiable(
      (data['suggestions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(limit),
    );
  }

  List<String>? _readCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }

    // Reinsert to keep the map ordered by most-recent access.
    _cache.remove(key);
    _cache[key] = entry;
    return entry.suggestions;
  }

  void _writeCache(
    String key,
    String query,
    int limit,
    List<String> suggestions,
  ) {
    _cache.remove(key);
    _cache[key] = _SuggestionCacheEntry(
      query: query,
      limit: limit,
      suggestions: suggestions,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
    _removeExpiredEntries();
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void _removeExpiredEntries() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => entry.expiresAt.isBefore(now));
  }

  String _cacheKey(String query, int limit) =>
      '${_normalizeForComparison(query)}::$limit';

  String _cleanQuery(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  String _normalizeForComparison(String value) =>
      _cleanQuery(value.replaceAll('#', ' ')).toLowerCase();
}

class _SuggestionCacheEntry {
  const _SuggestionCacheEntry({
    required this.query,
    required this.limit,
    required this.suggestions,
    required this.expiresAt,
  });

  final String query;
  final int limit;
  final List<String> suggestions;
  final DateTime expiresAt;
}
