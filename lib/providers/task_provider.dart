import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/task.dart';

final tasksStreamProvider = StreamProvider.family<List<Task>, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('tasks')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  });
});

final taskCountsProvider = Provider.family<Map<TaskStatus, int>, String>((ref, userId) {
  final tasksAsync = ref.watch(tasksStreamProvider(userId));
  return tasksAsync.maybeWhen(
    data: (tasks) {
      final counts = {
        TaskStatus.undone: 0,
        TaskStatus.inProgress: 0,
        TaskStatus.fulfilled: 0,
      };
      for (final task in tasks) {
        counts[task.status] = (counts[task.status] ?? 0) + 1;
      }
      return counts;
    },
    orElse: () => {
      TaskStatus.undone: 0,
      TaskStatus.inProgress: 0,
      TaskStatus.fulfilled: 0,
    },
  );
});

