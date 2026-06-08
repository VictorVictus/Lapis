import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:firebase_auth/firebase_auth.dart';

final subTaskServiceProvider = Provider<SubTaskService>((ref) => SubTaskService());

class SubTaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SubTask>> getSubTasks(String taskId) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection('subtasks')
        .where('taskId', isEqualTo: taskId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SubTask.fromMap(doc.data(), doc.id))
              .toList()
              ..sort((a, b) => a.order.compareTo(b.order)),
        );
  }

  Future<void> createSubTask(SubTask subTask) async {
    await _firestore.collection('subtasks').doc(subTask.id).set(subTask.toMap());
  }

  String generateId() {
    return _firestore.collection('subtasks').doc().id;
  }

  Future<void> updateSubTask(SubTask subTask) async {
    await _firestore.collection('subtasks').doc(subTask.id).update(subTask.toMap());
  }

  Future<void> deleteSubTask(String subTaskId) async {
    await _firestore.collection('subtasks').doc(subTaskId).delete();
  }
}
