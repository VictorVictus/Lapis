import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:to_do_app/services/subtask_service.dart';
import 'package:to_do_app/services/group_service.dart';

class SubTaskQuery {
  final String taskId;
  final String? groupId;

  const SubTaskQuery({required this.taskId, this.groupId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubTaskQuery && taskId == other.taskId && groupId == other.groupId;

  @override
  int get hashCode => Object.hash(taskId, groupId);
}

final unifiedSubTasksProvider = StreamProvider.family<List<SubTask>, SubTaskQuery>((ref, query) {
  if (query.groupId != null) {
    final groupService = ref.read(groupServiceProvider);
    return groupService.subTasksStream(query.groupId!, query.taskId).map(
      (list) => list.map((gs) => gs.toSubTask()).toList(),
    );
  }
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref.read(subTaskServiceProvider).getSubTasks(query.taskId, userId);
});
