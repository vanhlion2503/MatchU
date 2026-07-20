import 'package:cloud_functions/cloud_functions.dart';

class PostShareMetricResult {
  const PostShareMetricResult({
    required this.externalShareCount,
    required this.counted,
  });

  final int externalShareCount;
  final bool counted;
}

abstract interface class PostShareMetricsRepository {
  Future<PostShareMetricResult> recordShare({
    required String postId,
    required String eventId,
    required String method,
  });
}

class FirebasePostShareMetricsRepository implements PostShareMetricsRepository {
  FirebasePostShareMetricsRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<PostShareMetricResult> recordShare({
    required String postId,
    required String eventId,
    required String method,
  }) async {
    final callable = _functions.httpsCallable('recordPostExternalShare');
    final response = await callable.call(<String, dynamic>{
      'postId': postId,
      'eventId': eventId,
      'method': method,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawCount = data['externalShareCount'];
    return PostShareMetricResult(
      externalShareCount: rawCount is num ? rawCount.toInt() : 0,
      counted: data['counted'] == true,
    );
  }
}
