import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/user_profile_report_model.dart';

class UserProfileReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> submitReport(UserProfileReportModel report) async {
    final fromUid = report.fromUid.trim();
    final toUid = report.toUid.trim();

    if (fromUid.isEmpty || toUid.isEmpty) {
      throw StateError('Thiếu thông tin báo cáo.');
    }

    if (fromUid == toUid) {
      throw StateError('Bạn không thể báo cáo chính mình.');
    }

    final reportRef = _db.collection('userProfileReports').doc();
    final userRef = _db.collection('users').doc(toUid);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw StateError('Không tìm thấy người dùng này.');
      }

      final rawTotal = userSnap.data()?['totalReports'];
      final oldReports = rawTotal is num ? rawTotal.toInt() : 0;

      tx.set(reportRef, report.toJson());
      tx.update(userRef, {'totalReports': oldReports + 1});
    });
  }
}
