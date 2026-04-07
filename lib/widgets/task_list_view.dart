import 'package:flutter/material.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/widgets/task_list_item.dart';
import 'package:to_do_app/widgets/skeleton_task_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:to_do_app/widgets/empty_state_widget.dart';
import 'dart:developer';

class TaskListView extends ConsumerWidget {
  final String userId;
  final int selectedIndex;

  const TaskListView({
    super.key,
    required this.userId,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider(userId));
    final searchQuery = ref.watch(searchQueryProvider);

    return tasksAsync.when(
      data: (allTasks) {
        final tasks = allTasks.where((task) {
          // 1. Status Filter
          final matchesStatus = () {
            switch (selectedIndex) {
              case 0:
                return task.status == TaskStatus.undone;
              case 1:
                return task.status == TaskStatus.inProgress;
              case 2:
                return task.status == TaskStatus.fulfilled;
              default:
                return true;
            }
          }();

          // 2. Search Filter
          final matchesSearch = searchQuery.isEmpty || 
              task.title.toLowerCase().contains(searchQuery.toLowerCase());

          return matchesStatus && matchesSearch;
        }).toList();


        if (tasks.isEmpty) {
          return const EmptyStateWidget();
        }


        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return TaskListItem(
              key: ValueKey(task.id),
              task: task,
              onComplete: () {},
              selectedIndex: selectedIndex,
            );
          },
        );
      },
      loading: () => ListView.builder(
        itemCount: 4, 
        physics: const NeverScrollableScrollPhysics(), 
        itemBuilder: (context, index) => const SkeletonTaskItem(),
      ),
      error: (error, stack) {
        log('TaskListView error: $error');
        return const Center(
          child: Text(
            'Error loading tasks',
            style: TextStyle(color: Colors.white70),
          ),
        );
      },
    );
  }
}
