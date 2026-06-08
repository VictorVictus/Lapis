import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/models/subclasses/group_task.dart';
import 'package:to_do_app/services/group_service.dart';

final groupListProvider = StreamProvider.family<List<Group>, String>((ref, userId) {
  return ref.read(groupServiceProvider).getGroups(userId);
});

final groupMemberStreamProvider = StreamProvider.family<GroupMember?, ({String groupId, String uid})>(
  (ref, params) => ref.read(groupServiceProvider).memberStream(params.groupId, params.uid),
);

final groupMembersStreamProvider = StreamProvider.family<List<GroupMember>, String>(
  (ref, groupId) => ref.read(groupServiceProvider).membersStream(groupId),
);

final groupTaskListProvider = StreamProvider.family<List<GroupTask>, String>((ref, groupId) {
  return ref.read(groupServiceProvider).tasksStream(groupId);
});

final groupSubTaskListProvider = StreamProvider.family<List<GroupSubTask>, ({String groupId, String taskId})>(
  (ref, params) => ref.read(groupServiceProvider).subTasksStream(params.groupId, params.taskId),
);
