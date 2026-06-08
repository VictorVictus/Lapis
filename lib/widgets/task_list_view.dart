import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/widgets/task_list_item.dart';
import 'package:to_do_app/widgets/skeleton_task_item.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/unified_task_provider.dart';
import 'package:to_do_app/widgets/empty_state_widget.dart';
import 'package:to_do_app/core/smart_filter_utils.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _matchesSmartFilter(Task task, SmartFilter filter) =>
      matchesSmartFilter(task, filter);

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(dashboardProvider.select((state) => state.searchQuery));
    final smartFilter = ref.watch(dashboardProvider.select((state) => state.smartFilter));
    final sortBy = ref.watch(dashboardProvider.select((state) => state.sortBy));
    final tasksAsync = ref.watch(unifiedTasksProvider(widget.userId));

    return tasksAsync.when(
      data: (allTasks) {
        final selectedStatus = TaskStatus.values[widget.selectedIndex];
        final statusFiltered = allTasks.where((t) => t.status == selectedStatus).toList();
        final query = searchQuery.toLowerCase();
        final tasks = statusFiltered.where((task) {
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

        final groupBy = ref.watch(dashboardProvider.select((s) => s.groupBy));
        if (groupBy == GroupBy.none) {
          return _buildFlatList(tasks);
        }

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
            final key = task.priority.displayName;
            groups.putIfAbsent(key, () => []);
            if (!groupOrder.contains(key)) groupOrder.add(key);
            groups[key]!.add(task);
          }
        }

        return ListView(
          controller: _scrollController,
          children: [
            for (final key in groupOrder)
              ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  '$key (${groups[key]!.length})',
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
      },
      loading: () => ListView.builder(
        itemCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => const SkeletonTaskItem(),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Error loading tasks', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text(e.toString(), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatList(List<Task> tasks) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: tasks.length,
      itemBuilder: (context, index) => _buildTaskItem(tasks[index]),
    );
  }

  Widget _buildTaskItem(Task task) {
    return TaskListItem(
      key: ValueKey(task.id),
      task: task,
      selectedIndex: widget.selectedIndex,
      userInitial: widget.userInitial,
    );
  }
}
