import 'package:flutter/material.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/widgets/task_list_item.dart';
import 'package:to_do_app/widgets/skeleton_task_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/widgets/empty_state_widget.dart';
import 'dart:developer';

class TaskListView extends ConsumerStatefulWidget {
  final String userId;
  final int selectedIndex;
  final String userInitial;

  const TaskListView({
    super.key,
    required this.userId,
    required this.selectedIndex,
    this.userInitial = '?',
  });

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  Future<void> _onReorder(int oldIndex, int newIndex, List<Task> tasks) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<Task>.of(tasks)
      ..removeAt(oldIndex)
      ..insert(newIndex, tasks[oldIndex]);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < reordered.length; i++) {
      final t = reordered[i];
      final newOrder = i.toDouble();
      if (t.order != newOrder) {
        batch.update(
          FirebaseFirestore.instance.collection('tasks').doc(t.id),
          {'order': newOrder},
        );
      }
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error reordering tasks: $e');
    }
  }

  bool _matchesSmartFilter(Task task, SmartFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case SmartFilter.all:
        return true;
      case SmartFilter.today:
        return task.scheduledAt != null &&
            task.scheduledAt!.day == now.day &&
            task.scheduledAt!.month == now.month &&
            task.scheduledAt!.year == now.year;
      case SmartFilter.thisWeek:
        if (task.scheduledAt == null) return false;
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return task.scheduledAt!.isAfter(weekStart.subtract(const Duration(hours: 1)));
      case SmartFilter.overdue:
        return task.deadline != null && task.deadline!.isBefore(now);
      case SmartFilter.highPriority:
        return task.priority == TaskPriority.high;
      case SmartFilter.hasDeadline:
        return task.deadline != null;
      case SmartFilter.noDeadline:
        return task.deadline == null;
      case SmartFilter.thisMonth:
        if (task.scheduledAt == null) return false;
        return task.scheduledAt!.month == now.month &&
            task.scheduledAt!.year == now.year;
      case SmartFilter.recurring:
        return task.type == TaskType.recurrent;
    }
  }

  Widget _buildGroupedList(List<Task> tasks) {
    final groupBy = ref.watch(dashboardProvider.select((s) => s.groupBy));
    if (groupBy == GroupBy.none) return _buildFlatList(tasks);

    final Map<String, List<Task>> groups = {};
    final List<String> groupOrder = [];
    if (groupBy == GroupBy.category) {
      for (final task in tasks) {
        final key = task.category.name;
        groups.putIfAbsent(key, () => []);
        if (!groupOrder.contains(key)) groupOrder.add(key);
        groups[key]!.add(task);
      }
    } else {
      for (final task in tasks) {
        final key = task.priority.name;
        groups.putIfAbsent(key, () => []);
        if (!groupOrder.contains(key)) groupOrder.add(key);
        groups[key]!.add(task);
      }
    }

    return ListView(
      children: [
        for (final key in groupOrder)
          ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              groupBy == GroupBy.category
                  ? '$key (${groups[key]!.length})'
                  : '${key[0].toUpperCase()}${key.substring(1)} (${groups[key]!.length})',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            children: groups[key]!.map((task) => TaskListItem(
              key: ValueKey(task.id),
              task: task,
              selectedIndex: widget.selectedIndex,
              userInitial: widget.userInitial,
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildFlatList(List<Task> tasks) {
    final selectionMode = ref.watch(dashboardProvider.select((s) => s.selectionMode));
    if (selectionMode) {
      return ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskListItem(
            key: ValueKey(task.id),
            task: task,
            selectedIndex: widget.selectedIndex,
            userInitial: widget.userInitial,
          );
        },
      );
    }
    return ReorderableListView.builder(
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, tasks),
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskListItem(
          key: ValueKey(task.id),
          task: task,
          selectedIndex: widget.selectedIndex,
          userInitial: widget.userInitial,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(filteredTasksProvider((userId: widget.userId, selectedIndex: widget.selectedIndex)));
    final searchQuery = ref.watch(dashboardProvider.select((state) => state.searchQuery));
    final smartFilter = ref.watch(dashboardProvider.select((state) => state.smartFilter));
    final sortBy = ref.watch(dashboardProvider.select((state) => state.sortBy));

    return tasksAsync.when(
      data: (allTasks) {
        final query = searchQuery.toLowerCase();
        final tasks = allTasks.where((task) {
          final matchesSearch = searchQuery.isEmpty ||
              task.title.toLowerCase().contains(query) ||
              (task.notes != null && task.notes!.toLowerCase().contains(query));
          final matchesSmart = _matchesSmartFilter(task, smartFilter);
          return matchesSearch && matchesSmart;
        }).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            switch (sortBy) {
              case SortBy.deadline:
                final aDl = a.deadline;
                final bDl = b.deadline;
                if (aDl == null && bDl == null) return 0;
                if (aDl == null) return 1;
                if (bDl == null) return -1;
                return aDl.compareTo(bDl);
              case SortBy.priority:
                return b.priority.index.compareTo(a.priority.index);
              case SortBy.created:
                return a.createdAt.compareTo(b.createdAt);
              case SortBy.order:
                return a.order.compareTo(b.order);
            }
          });

        if (tasks.isEmpty) {
          return const EmptyStateWidget();
        }

        return _buildGroupedList(tasks);
      },
      loading: () => ListView.builder(
        itemCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => const SkeletonTaskItem(),
      ),
      error: (error, stack) {
        log('TaskListView error: $error');
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Error loading tasks',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.invalidate(
                  filteredTasksProvider((
                    userId: widget.userId,
                    selectedIndex: widget.selectedIndex,
                  )),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white70),
                label: const Text('Retry', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      },
    );
  }
}
