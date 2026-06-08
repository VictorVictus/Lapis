import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/services/group_service.dart';
import 'package:to_do_app/services/task_service.dart';

final unifiedTasksProvider = StreamProvider.family<List<Task>, String>((ref, userId) {
  final groupService = ref.read(groupServiceProvider);
  final taskService = ref.read(taskServiceProvider);

  final controller = StreamController<List<Task>>();

  List<Task> personalTasks = [];
  Map<String, List<Task>> groupTasksAsTasks = {};
  bool personalLoaded = false;
  List<StreamSubscription> taskSubs = [];
  StreamSubscription? userDocSub;

  void emit() {
    if (!personalLoaded) return;
    final all = <Task>[...personalTasks];
    for (final entry in groupTasksAsTasks.values) {
      all.addAll(entry);
    }
    all.sort((a, b) {
      final cmp = a.order.compareTo(b.order);
      if (cmp != 0) return cmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    controller.add(all);
  }

  ref.onDispose(() {
    userDocSub?.cancel();
    for (final s in taskSubs) { s.cancel(); }
    controller.close();
  });

  ref.onDispose(taskService.getTasksForUser(userId).listen(
    (tasks) {
      personalTasks = tasks.where((t) => !t.isArchived).toList();
      personalLoaded = true;
      emit();
    },
    onError: (e) => controller.addError(e),
  ).cancel);

  userDocSub = FirebaseFirestore.instance.collection('users').doc(userId).snapshots().listen((snap) {
    for (final s in taskSubs) { s.cancel(); }
    taskSubs = [];
    groupTasksAsTasks.clear();

    final data = snap.data();
    final groupIds = (data?['groupIds'] as List<dynamic>?)?.cast<String>() ?? [];
    if (groupIds.isEmpty) {
      emit();
      return;
    }

    Future.wait(groupIds.map((id) => FirebaseFirestore.instance.collection('groups').doc(id).get())).then((snapshots) {
      for (final doc in snapshots) {
        if (!doc.exists) continue;
        final group = Group.fromMap(doc.data()!, doc.id);
        final sub = groupService.tasksStream(group.id).listen((groupTasks) {
          groupTasksAsTasks[group.id] = groupTasks.map((gt) => gt.toTask(groupName: group.name)).toList();
          emit();
        });
        taskSubs.add(sub);
      }
      emit();
    });
  });

  return controller.stream;
});
