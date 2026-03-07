import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';

class ReputationService {
  ReputationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  static const String _defaultTimezone = "Asia/Ho_Chi_Minh";

  Future<ReputationDailyState> touchDailyLoginTask({
    String timezone = _defaultTimezone,
    String source = "app_open",
  }) async {
    final callable = _functions.httpsCallable("touchReputationDailyOnAppOpen");
    const eventId = "loginDaily_app_open";

    final result = await _callWithRetry(callable, <String, dynamic>{
      "timezone": timezone,
      "eventId": eventId,
      "source": source,
    });

    final payload = _asMap(result.data);
    final stateMap = _asMap(payload["state"]);
    return ReputationDailyState.fromMap(stateMap);
  }

  Future<ReputationDailyState> getDailyState({
    String timezone = _defaultTimezone,
  }) async {
    final callable = _functions.httpsCallable("getReputationDailyState");
    final result = await _callWithRetry(callable, <String, dynamic>{
      "timezone": timezone,
    });

    final payload = _asMap(result.data);
    final stateMap = _asMap(payload["state"]);
    return ReputationDailyState.fromMap(stateMap);
  }

  Future<ReputationClaimResponse> claimTask({
    required String taskId,
    String timezone = _defaultTimezone,
  }) async {
    final callable = _functions.httpsCallable("claimReputationTask");
    final claimId =
        "claim_${taskId}_${DateTime.now().toUtc().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}";

    final result = await _callWithRetry(callable, <String, dynamic>{
      "taskId": taskId,
      "timezone": timezone,
      "claimId": claimId,
    });

    final payload = _asMap(result.data);
    final claimMap = _asMap(payload["claim"]);
    final stateMap = _asMap(payload["state"]);

    return ReputationClaimResponse(
      claim: ReputationClaimResult.fromMap(claimMap),
      state: ReputationDailyState.fromMap(stateMap),
    );
  }

  Future<void> touchDailyLoginTaskSilently({
    String timezone = _defaultTimezone,
    String source = "app_open",
  }) async {
    try {
      await touchDailyLoginTask(timezone: timezone, source: source);
    } catch (error) {
      debugPrint("Silent daily login touch failed: $error");
    }
  }

  Future<HttpsCallableResult<dynamic>> _callWithRetry(
    HttpsCallable callable,
    Map<String, dynamic> payload,
  ) async {
    final retryDelays = <Duration>[
      const Duration(milliseconds: 700),
      const Duration(milliseconds: 1500),
      const Duration(milliseconds: 3000),
      const Duration(milliseconds: 6000),
    ];

    Object? lastError;

    for (int attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        return await callable.call(payload);
      } catch (error) {
        lastError = error;
        if (!_shouldRetry(error) || attempt >= retryDelays.length) {
          rethrow;
        }

        await Future<void>.delayed(retryDelays[attempt]);
      }
    }

    throw lastError ?? StateError("Callable retry failed without error.");
  }

  bool _shouldRetry(Object error) {
    if (error is! FirebaseFunctionsException) return false;

    final code = error.code.toLowerCase().replaceAll("_", "-");
    return code == "resource-exhausted" ||
        code == "unavailable" ||
        code == "deadline-exceeded";
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }
}
