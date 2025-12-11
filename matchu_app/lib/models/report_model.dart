class ReportModel {
  final String reportId;
  final String reporterUid;
  final String targetUid;
  final String roomId;
  final String reason;
  final DateTime createdAt;

  ReportModel({
    required this.reportId,
    required this.reporterUid,
    required this.targetUid,
    required this.roomId,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        "reportId": reportId,
        "reporterUid": reporterUid,
        "targetUid": targetUid,
        "roomId": roomId,
        "reason": reason,
        "createdAt": createdAt.toIso8601String(),
      };

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      reportId: json["reportId"],
      reporterUid: json["reporterUid"],
      targetUid: json["targetUid"],
      roomId: json["roomId"],
      reason: json["reason"],
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}
