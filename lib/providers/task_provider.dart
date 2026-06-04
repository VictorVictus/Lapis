import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';

import 'package:to_do_app/services/task_service.dart';

final tasksStreamProvider = StreamProvider.autoDispose.family<List<Task>, String>((ref, userId) {
  return ref.read(taskServiceProvider).getTasksForUser(userId);
});

final taskCountsProvider = FutureProvider.autoDispose.family<Map<TaskStatus, int>, String>((ref, userId) async {
  return ref.read(taskServiceProvider).getTaskCounts(userId);
});

final archivedTasksProvider = StreamProvider.autoDispose.family<List<Task>, String>((ref, userId) {
  return ref.read(taskServiceProvider).getArchivedTasks(userId);
});

