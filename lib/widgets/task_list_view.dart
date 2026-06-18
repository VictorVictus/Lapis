import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/widgets/task_list_item.dart';
import 'package:to_do_app/widgets/skeleton_task_item.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/unified_task_provider.dart';
import 'package:to_do_app/services/task_service.dart';
import 'package:to_do_app/services/group_service.dart';
import 'package:to_do_app/widgets/empty_state_widget.dart';
import 'package:to_do_app/core/smart_filter_utils.dart';
import 'package:to_do_app/providers/sections_provider.dart';

class TaskListView extends ConsumerStatefulWidget {
  final String userId;
  final int selectedIndex;
  final String userInitial;
  final String? labelFilterId;

  const TaskListView({
    super.key,
    required this.userId,
    required this.selectedIndex,
    this.userInitial = '?',
    this.labelFilterId,
  });

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  final ScrollController _scrollController = ScrollController();
  Timer? _reorderDebounce;

  @override
  void dispose() {
    _reorderDebounce?.cancel();
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
          final matchesLabel = widget.labelFilterId == null || task.labelIds.contains(widget.labelFilterId);
          return matchesSearch && matchesSmart && matchesLabel;
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

        final groupBy = ref.watch(dashboardProvider.select((s) => s.groupBy));

        Widget content;
        if (tasks.isEmpty) {
          content = const EmptyStateWidget();
        } else if (groupBy == GroupBy.none) {
          content = _buildFlatList(tasks);
        } else {
          content = _buildGroupedList(tasks, groupBy);
        }

        return content;
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

  Future<void> _clearAllCompleted(List<Task> tasks) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear completed'),
        content: Text('Delete all ${tasks.length} completed tasks?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final taskService = ref.read(taskServiceProvider);
    final groupService = ref.read(groupServiceProvider);
    for (final task in tasks) {
      try {
        if (task.groupId != null) {
          await groupService.deleteTask(task.groupId!, task.id);
        } else {
          await taskService.deleteTask(task.id, task.userId);
        }
      } catch (e) {
        debugPrint('Error clearing task ${task.id}: $e');
      }
    }
  }

  Widget _buildFlatList(List<Task> tasks) {
    final isDone = TaskStatus.values[widget.selectedIndex] == TaskStatus.fulfilled;
    final sortBy = ref.watch(dashboardProvider.select((s) => s.sortBy));
    final canReorder = sortBy == SortBy.order && !isDone;

    if (canReorder) {
      return ReorderableListView.builder(
        itemCount: tasks.length,
        onReorder: (oldIndex, newIndex) => _onReorder(tasks, oldIndex, newIndex),
        proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
          child: child,
        ),
        itemBuilder: (context, index) {
          return _buildTaskItem(tasks[index]);
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: tasks.length + (isDone && tasks.length >= 2 ? 1 : 0),
      itemBuilder: (context, index) {
        if (isDone && tasks.length >= 2 && index == 0) {
          return _buildClearAllHeader(tasks);
        }
        final taskIndex = isDone && tasks.length >= 2 ? index - 1 : index;
        return _buildTaskItem(tasks[taskIndex]);
      },
    );
  }

  void _onReorder(List<Task> tasks, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<Task>.from(tasks);
    final task = updated.removeAt(oldIndex);
    updated.insert(newIndex, task);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < updated.length; i++) {
      final t = updated[i];
      if (t.order == i.toDouble()) continue;
      if (t.groupId != null) {
        batch.update(
          FirebaseFirestore.instance.collection('groups').doc(t.groupId).collection('tasks').doc(t.id),
          {'order': i.toDouble()},
        );
      } else {
        batch.update(
          FirebaseFirestore.instance.collection('tasks').doc(t.id),
          {'order': i.toDouble()},
        );
      }
    }
    _reorderDebounce?.cancel();
    _reorderDebounce = Timer(const Duration(milliseconds: 500), () {
      batch.commit().catchError((e) => debugPrint('Reorder batch error: $e'));
    });
  }

  Widget _buildClearAllHeader(List<Task> tasks) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            onPressed: () => _clearAllCompleted(tasks),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_sweep, size: 16, color: CupertinoColors.destructiveRed.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text(
                  'Clear all (${tasks.length})',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.destructiveRed.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Task> tasks, GroupBy groupBy) {
    final isDone = TaskStatus.values[widget.selectedIndex] == TaskStatus.fulfilled;

    if (groupBy == GroupBy.section) {
      return _buildSectionGroupedList(tasks, isDone);
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
        if (isDone && tasks.length >= 2) _buildClearAllHeader(tasks),
        for (final key in groupOrder)
          ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            '$key (${groups[key]!.length})',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          children: groups[key]!.map((task) => _buildTaskItem(task)).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionGroupedList(List<Task> tasks, bool isDone) {
    final sectionsAsync = ref.watch(userSectionsProvider(widget.userId));
    final definedSections = sectionsAsync.asData?.value ?? [];

    final Map<String, List<Task>> groups = {};
    final List<String> groupOrder = [];

    for (final s in definedSections) {
      groups[s.name] = [];
      groupOrder.add(s.name);
    }

    final noSection = <Task>[];
    for (final task in tasks) {
      if (task.section != null) {
        final section = definedSections.where((s) => s.id == task.section).firstOrNull;
        final key = section?.name ?? 'Other';
        groups.putIfAbsent(key, () => []);
        if (!groupOrder.contains(key)) {
          groupOrder.add(key);
        }
        groups[key]!.add(task);
      } else {
        noSection.add(task);
      }
    }

    groupOrder.removeWhere((k) => groups[k]!.isEmpty);

    return ListView(
      controller: _scrollController,
      children: [
        if (isDone && tasks.length >= 2) _buildClearAllHeader(tasks),
        if (noSection.isNotEmpty)
          ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              'General (${noSection.length})',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            children: noSection.map((task) => _buildTaskItem(task)).toList(),
          ),
        for (final key in groupOrder)
          ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              '$key (${groups[key]!.length})',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            children: groups[key]!.map((task) => _buildTaskItem(task)).toList(),
          ),
      ],
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
