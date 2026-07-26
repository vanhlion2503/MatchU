import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:matchu_app/models/queue_user_model.dart';
import 'package:matchu_app/models/account_access/account_access_model.dart';
import 'package:matchu_app/services/user/account_access_service.dart';

/// Repository for the server-authoritative matching session.
class MatchingService {
  MatchingService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    AccountAccessService? accountAccessService,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _accountAccessService =
           accountAccessService ?? AccountAccessService(firestore: firestore);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final AccountAccessService _accountAccessService;

  static const String queueCollection = 'tempChatMatchingQueue';
  String? _activeSessionId;

  Future<String?> matchUser(
    QueueUserModel seeker, {
    required String myAnonymousAvatar,
    required String sessionId,
  }) async {
    await _accountAccessService.ensureAllowed(AccountFeature.matching);
    _activeSessionId = sessionId;
    final result = await _functions
        .httpsCallable('startTempChatMatching')
        .call({
          'sessionId': sessionId,
          'targetGender': seeker.targetGender,
          'anonymousAvatar': myAnonymousAvatar,
          'matchingMode': seeker.matchingMode.value,
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['roomId']?.toString();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenSession(String uid) {
    return _firestore.collection(queueCollection).doc(uid).snapshots();
  }

  Future<void> dequeue(String uid, {String? sessionId}) async {
    final activeSession = sessionId ?? _activeSessionId;
    _activeSessionId = null;
    await _functions.httpsCallable('cancelTempChatMatching').call({
      'sessionId': activeSession,
    });
  }

  Future<void> forceUnlock(String uid) => dequeue(uid);
}
