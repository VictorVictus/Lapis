import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/widgets/task_list_item.dart';
import 'package:to_do_app/widgets/skeleton_task_item.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
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
  List<Task> _allTasks = [];
  bool _initialLoading = true;
  String? _error;
  StreamSubscription<QuerySnapshot>? _snapshotSub;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(TaskListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex || oldWidget.userId != widget.userId) {
      _resetAndReload();
    }
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetAndReload() {
    _snapshotSub?.cancel();
    _allTasks = [];
    _initialLoading = true;
    _error = null;
    _initStream();
  }

  void _initStream() {
    _snapshotSub = FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .listen(
      (snapshot) {
        _allTasks = snapshot.docs
            .map((d) => Task.fromMap(d.data(), d.id))
            .where((t) => !t.isArchived)
            .toList();
        _initialLoading = false;
        _error = null;
        if (mounted) setState(() {});
      },
      onError: (e) {
        _error = e.toString();
        _initialLoading = false;
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final statusTasks = _allTasks.where((t) => t.status == TaskStatus.values[widget.selectedIndex]).toList();
    final reordered = List<Task>.of(statusTasks)
      ..removeAt(oldIndex)
      ..insert(newIndex, statusTasks[oldIndex]);

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

  bool _matchesSmartFilter(Task task, SmartFilter filter) =>
      matchesSmartFilter(task, filter);

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
            )            ).toList(),
          ),
      ],
    );
  }

  Widget _buildFlatList(List<Task> tasks) {
    final selectionMode = ref.watch(dashboardProvider.select((s) => s.selectionMode));
    if (selectionMode) {
      return ListView.builder(
        controller: _scrollController,
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
      buildDefaultDragHandles: false,
      scrollController: _scrollController,
      itemCount: tasks.length,
      onReorder: _onReorder,
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
    final searchQuery = ref.watch(dashboardProvider.select((state) => state.searchQuery));
    final smartFilter = ref.watch(dashboardProvider.select((state) => state.smartFilter));
    final sortBy = ref.watch(dashboardProvider.select((state) => state.sortBy));

    if (_initialLoading) {
      return ListView.builder(
        itemCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => const SkeletonTaskItem(),
      );
    }

    if (_error != null && _allTasks.isEmpty) {
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
              onPressed: _resetAndReload,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text('Retry', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }

    final selectedStatus = TaskStatus.values[widget.selectedIndex];
    final statusFiltered = _allTasks.where((t) => t.status == selectedStatus).toList();
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

    return _buildGroupedList(tasks);
  }
}
