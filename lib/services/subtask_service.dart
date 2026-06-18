import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:to_do_app/services/sync_coordinator.dart';

final subTaskServiceProvider = Provider<SubTaskService>((ref) => SubTaskService(ref));

class SubTaskService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SubTaskService(this._ref);

  Stream<List<SubTask>> getSubTasks(String taskId, String userId) {
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
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore.collection('subtasks').doc(subTask.id).set(subTask.toMap());
    });
  }

  String generateId() {
    return _firestore.collection('subtasks').doc().id;
  }

  Future<void> updateSubTask(SubTask subTask) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore.collection('subtasks').doc(subTask.id).update(subTask.toMap());
    });
  }

  Future<void> deleteSubTask(String subTaskId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore.collection('subtasks').doc(subTaskId).delete();
    });
  }
}
