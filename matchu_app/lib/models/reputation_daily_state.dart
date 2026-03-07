class ReputationDailyTask {
  final String id;
  final int target;
  final int progress;
  final int reward;
  final bool claimed;
  final int claimedReward;
  final bool isCompleted;
  final int? claimedAtMillis;

  const ReputationDailyTask({
    required this.id,
    required this.target,
    required this.progress,
    required this.reward,
    required this.claimed,
    required this.claimedReward,
    required this.isCompleted,
    required this.claimedAtMillis,
  });

  factory ReputationDailyTask.fromMap(String id, Map<String, dynamic> data) {
    final target = _asInt(data["target"], fallback: 1, min: 1);
    return ReputationDailyTask(
      id: id,
      target: target,
      progress: _asInt(data["progress"], min: 0, max: target),
      reward: _asInt(data["reward"], min: 0),
      claimed: _asBool(data["claimed"]),
      claimedReward: _asInt(data["claimedReward"], min: 0),
      isCompleted:
          _asBool(data["isCompleted"]) ||
          _asInt(data["progress"], min: 0, max: target) >= target,
      claimedAtMillis: _asNullableInt(data["claimedAtMillis"]),
    );
  }
}

class ReputationDailyState {
  final String dateKey;
  final String timezone;
  final int dailyCap;
  final int todayClaimed;
  final int reputationScore;
  final int reputationMax;
  final bool canEarnMore;
  final Map<String, ReputationDailyTask> tasks;

  const ReputationDailyState({
    required this.dateKey,
    required this.timezone,
    required this.dailyCap,
    required this.todayClaimed,
    required this.reputationScore,
    required this.reputationMax,
    required this.canEarnMore,
    required this.tasks,
  });

  factory ReputationDailyState.fromMap(Map<String, dynamic> data) {
    final tasksRaw = data["tasks"];
    final tasks = <String, ReputationDailyTask>{};
    if (tasksRaw is Map) {
      tasksRaw.forEach((key, value) {
        if (key is! String || value is! Map) return;
        tasks[key] = ReputationDailyTask.fromMap(
          key,
          Map<String, dynamic>.from(value),
        );
      });
    }

    final dailyCap = _asInt(data["dailyCap"], fallback: 10, min: 1);
    final todayClaimed = _asInt(data["todayClaimed"], min: 0, max: dailyCap);
    final reputationMax = _asInt(data["reputationMax"], fallback: 100, min: 1);
    final reputationScore = _asInt(
      data["reputationScore"],
      fallback: reputationMax,
      min: 0,
      max: reputationMax,
    );

    return ReputationDailyState(
      dateKey: (data["dateKey"] ?? "").toString(),
      timezone: (data["timezone"] ?? "").toString(),
      dailyCap: dailyCap,
      todayClaimed: todayClaimed,
      reputationScore: reputationScore,
      reputationMax: reputationMax,
      canEarnMore: _asBool(data["canEarnMore"]),
      tasks: tasks,
    );
  }

  ReputationDailyTask? get loginDailyTask => tasks["loginDaily"];

  int get todayRemaining => (dailyCap - todayClaimed).clamp(0, dailyCap);

  bool get hasReachedMax => reputationScore >= reputationMax;
}

class ReputationClaimResult {
  final String taskId;
  final int requested;
  final int awarded;
  final String reason;
  final int reputationBefore;
  final int reputationAfter;
  final int todayClaimedBefore;
  final int todayClaimedAfter;

  const ReputationClaimResult({
    required this.taskId,
    required this.requested,
    required this.awarded,
    required this.reason,
    required this.reputationBefore,
    required this.reputationAfter,
    required this.todayClaimedBefore,
    required this.todayClaimedAfter,
  });

  factory ReputationClaimResult.fromMap(Map<String, dynamic> data) {
    return ReputationClaimResult(
      taskId: (data["taskId"] ?? "").toString(),
      requested: _asInt(data["requested"], min: 0),
      awarded: _asInt(data["awarded"], min: 0),
      reason: (data["reason"] ?? "unknown").toString(),
      reputationBefore: _asInt(data["reputationBefore"], min: 0, max: 100),
      reputationAfter: _asInt(data["reputationAfter"], min: 0, max: 100),
      todayClaimedBefore: _asInt(data["todayClaimedBefore"], min: 0),
      todayClaimedAfter: _asInt(data["todayClaimedAfter"], min: 0),
    );
  }
}

class ReputationClaimResponse {
  final ReputationClaimResult claim;
  final ReputationDailyState state;

  const ReputationClaimResponse({required this.claim, required this.state});
}

int _asInt(dynamic value, {int fallback = 0, int? min, int? max}) {
  int parsed;
  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else if (value is String) {
    parsed = int.tryParse(value) ?? fallback;
  } else {
    parsed = fallback;
  }

  if (min != null && parsed < min) parsed = min;
  if (max != null && parsed > max) parsed = max;
  return parsed;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == "true" || normalized == "1") return true;
    if (normalized == "false" || normalized == "0") return false;
  }
  return fallback;
}
