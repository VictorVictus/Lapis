import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/label.dart';

final labelServiceProvider = Provider<LabelService>((ref) => LabelService());

class LabelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Label>> getLabels(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('labels')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Label.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> createLabel(Label label) async {
    await _firestore
        .collection('users')
        .doc(label.userId)
        .collection('labels')
        .doc(label.id)
        .set(label.toMap());
  }

  Future<void> updateLabel(Label label) async {
    await _firestore
        .collection('users')
        .doc(label.userId)
        .collection('labels')
        .doc(label.id)
        .update(label.toMap());
  }

  Future<void> deleteLabel(String userId, String labelId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('labels')
        .doc(labelId)
        .delete();
  }

  String generateId(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('labels')
        .doc()
        .id;
  }
}
