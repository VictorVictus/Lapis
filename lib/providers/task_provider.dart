import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';

import 'package:to_do_app/services/task_service.dart';
import 'package:to_do_app/providers/pagination_provider.dart';

typedef TaskFilterArgs = ({String userId, int selectedIndex});

final tasksStreamProvider = StreamProvider.autoDispose.family<List<Task>, String>((ref, userId) {
  return ref.read(taskServiceProvider).getTasksForUser(userId);
});

final filteredTasksProvider = StreamProvider.autoDispose.family<List<Task>, TaskFilterArgs>((ref, args) {
  final limit = ref.watch(taskLimitProvider);
  return ref.read(taskServiceProvider).getFilteredTasksStream(args.userId, args.selectedIndex, limit: limit);
});

final taskCountsProvider = FutureProvider.autoDispose.family<Map<TaskStatus, int>, String>((ref, userId) async {
  return ref.read(taskServiceProvider).getTaskCounts(userId);
});

final archivedTasksProvider = StreamProvider.autoDispose.family<List<Task>, String>((ref, userId) {
  return ref.read(taskServiceProvider).getArchivedTasks(userId);
});

