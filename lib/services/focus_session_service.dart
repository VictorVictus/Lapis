import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/focus_session.dart';

class FocusSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveSession(FocusSession session) async {
    await _firestore.collection('focus_sessions').doc(session.id).set(session.toMap());
  }

  Stream<List<FocusSession>> getSessions(String userId) {
    return _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => FocusSession.fromMap(doc.data(), doc.id)).toList());
  }

  Future<Map<String, int>> getStats(String userId) async {
    final snap = await _firestore
        .collection('focus_sessions')
        .where('userId', isEqualTo: userId)
        .get();
    int totalSeconds = 0;
    for (final doc in snap.docs) {
      totalSeconds += doc.data()['durationSeconds'] as int? ?? 0;
    }
    return {
      'totalSessions': snap.docs.length,
      'totalSeconds': totalSeconds,
    };
  }
}
