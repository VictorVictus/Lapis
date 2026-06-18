import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/section.dart';
import 'package:to_do_app/services/sync_coordinator.dart';

final sectionServiceProvider = Provider<SectionService>((ref) => SectionService(ref));

class SectionService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SectionService(this._ref);

  Stream<List<Section>> getSections(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sections')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Section.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> createSection(Section section) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('users')
          .doc(section.userId)
          .collection('sections')
          .doc(section.id)
          .set(section.toMap());
    });
  }

  Future<void> updateSection(Section section) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('users')
          .doc(section.userId)
          .collection('sections')
          .doc(section.id)
          .update(section.toMap());
    });
  }

  Future<void> deleteSection(String userId, String sectionId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sections')
          .doc(sectionId)
          .delete();
    });
  }

  String generateId(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sections')
        .doc()
        .id;
  }
}
