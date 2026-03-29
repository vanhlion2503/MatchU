class StatsModel {
  const StatsModel({
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
  });

  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;

  factory StatsModel.fromJson(Map<String, dynamic>? json) {
    return StatsModel(
      likeCount: _parseInt(json?['likeCount']),
      commentCount: _parseInt(json?['commentCount']),
      shareCount: _parseInt(json?['shareCount']),
      saveCount: _parseInt(json?['saveCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'saveCount': saveCount,
    };
  }

  StatsModel copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? saveCount,
  }) {
    return StatsModel(
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      saveCount: saveCount ?? this.saveCount,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
