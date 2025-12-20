import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/user_report_matching_model.dart';

class ReportMatchingService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> submitReport(
    UserReportMatchingModel report,
  ) async {
    final reportRef =
        _db.collection("userMatchingReports").doc();

    final userRef =
        _db.collection("users").doc(report.toUid);

    await _db.runTransaction((tx) async {
      // ================== READ FIRST ==================
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;

      final oldReports =
          (userSnap.data()?["totalReports"] ?? 0) as int;

      // ================== WRITE AFTER ==================
      tx.set(reportRef, report.toJson());

      tx.update(userRef, {
        "totalReports": oldReports + 1,
      });
    });
  }
}
