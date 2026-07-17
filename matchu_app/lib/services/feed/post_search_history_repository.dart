import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';

class PostSearchHistoryRepository {
  PostSearchHistoryRepository({GetStorage? storage, FirebaseAuth? auth})
    : _storage = storage ?? GetStorage(),
      _auth = auth ?? FirebaseAuth.instance;

  static const int maxItems = 10;

  final GetStorage _storage;
  final FirebaseAuth _auth;

  String get _storageKey {
    final uid = _auth.currentUser?.uid.trim();
    return 'post_search_history_${uid?.isNotEmpty == true ? uid : 'guest'}';
  }

  List<String> read() {
    final raw = _storage.read<List<dynamic>>(_storageKey) ?? const [];
    return raw
        .whereType<String>()
        .map(_cleanQuery)
        .where((query) => query.isNotEmpty)
        .take(maxItems)
        .toList(growable: false);
  }

  Future<List<String>> add(String rawQuery) async {
    final query = _cleanQuery(rawQuery);
    if (query.isEmpty) return read();

    final updated =
        read()
            .where((item) => item.toLowerCase() != query.toLowerCase())
            .toList();
    updated.insert(0, query);
    final limited = updated.take(maxItems).toList(growable: false);
    await _storage.write(_storageKey, limited);
    return limited;
  }

  Future<List<String>> remove(String rawQuery) async {
    final query = _cleanQuery(rawQuery).toLowerCase();
    final updated = read()
        .where((item) => item.toLowerCase() != query)
        .toList(growable: false);
    await _storage.write(_storageKey, updated);
    return updated;
  }

  Future<void> clear() => _storage.remove(_storageKey);

  String _cleanQuery(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
