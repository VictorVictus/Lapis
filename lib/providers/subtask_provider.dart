import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:to_do_app/services/subtask_service.dart';

final subTasksProvider = StreamProvider.family<List<SubTask>, String>((ref, taskId) {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref.read(subTaskServiceProvider).getSubTasks(taskId, userId);
});
