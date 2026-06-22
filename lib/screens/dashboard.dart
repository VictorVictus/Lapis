import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/models/subclasses/label.dart';
import 'package:to_do_app/widgets/task_list_view.dart';
import 'package:to_do_app/widgets/kanban_view.dart';
import 'package:to_do_app/screens/schedule_page.dart';
import 'package:to_do_app/widgets/add_task_sheet.dart';
import 'package:to_do_app/widgets/dashboard_header.dart';
import 'package:to_do_app/widgets/task_status_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/user_provider.dart';
import 'package:to_do_app/providers/sync_provider.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:to_do_app/providers/add_task_provider.dart';
import 'package:to_do_app/providers/categories_provider.dart';
import 'package:to_do_app/providers/label_providers.dart';
import 'package:to_do_app/services/task_service.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/services/group_service.dart';
import 'package:to_do_app/services/label_service.dart';
import 'package:to_do_app/services/share_service.dart';
import 'package:to_do_app/theme/app_theme.dart';
import 'package:to_do_app/widgets/notification_permission_dialog.dart';
import 'package:to_do_app/widgets/screen_pinning_dialog.dart';
import 'package:to_do_app/widgets/weekly_review_dialog.dart';
import 'package:to_do_app/services/widget_data_service.dart';

class Dashboard extends ConsumerStatefulWidget {
  final User user;
  const Dashboard({super.key, required this.user});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  final _quickAddController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String? _labelFilterId;
  StreamSubscription? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupNotifications());
    WidgetsBinding.instance.addPostFrameCallback((_) => _showScreenPinningDialog());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWeeklyReview());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSharedText());
    // Defer widget data refresh so the initial frame and Firestore listeners
    // settle before we fetch all tasks for the home-screen widget.
    WidgetsBinding.instance.addPostFrameCallback((_) => Future.delayed(
      const Duration(milliseconds: 1200),
      () { if (mounted) _refreshWidgetData(); },
    ));
    _shareSubscription = ShareService.onShared.stream.listen((text) {
      _openAddTaskSheetWithText(text);
    });
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _quickAddController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _setupNotifications() async {
    if (!mounted) return;
    await showNotificationPermissionRationale(context);
    if (!mounted) return;
    await NotificationService().requestPermissions();
  }

  Future<void> _showScreenPinningDialog() async {
    if (!mounted) return;
    await showScreenPinningDialogIfNeeded(context);
  }

  Future<void> _refreshWidgetData() async {
    await WidgetDataService.updateTodayTasks(widget.user.uid);
  }

  Future<void> _checkWeeklyReview() async {
    if (!mounted) return;
    await showWeeklyReviewIfNeeded(context, ref, widget.user.uid);
  }

  Future<void> _checkSharedText() async {
    final text = await ShareService.checkForPendingText();
    if (text != null && mounted) {
      _openAddTaskSheetWithText(text);
    }
  }

  void _showAddTaskChoice() {
    final groupService = ref.read(groupServiceProvider);
    final uid = widget.user.uid;

    groupService.getGroups(uid).first.then((groups) {
      if (!mounted) return;
      final actions = <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddTaskSheet(),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 18),
              SizedBox(width: 8),
              Text('Personal task'),
            ],
          ),
        ),
        if (groups.isNotEmpty) ...[
          for (final g in groups)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                if (!mounted) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddTaskSheet(groupId: g.id),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(g.name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
      ];

      actions.add(CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ));

      showCupertinoModalPopup(context: context, builder: (_) => CupertinoActionSheet(
        title: const Text('Add task to…'),
        actions: actions,
      ));
    });
  }

  void _openAddTaskSheetWithText(String text) {
    ref.read(addTaskProvider.notifier).updateTitle(text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTaskSheet(),
    );
  }

  ({String title, DateTime? scheduledAt, TaskPriority? priority}) _parseQuickAdd(String raw) {
    var text = raw.trim();
    TaskPriority? priority;

    final priorityPatterns = [
      (RegExp(r'\bhigh( priority)?\b', caseSensitive: false), TaskPriority.high),
      (RegExp(r'\bmedium( priority)?\b', caseSensitive: false), TaskPriority.medium),
      (RegExp(r'\blow( priority)?\b', caseSensitive: false), TaskPriority.low),
      (RegExp(r'\bp[1-3]\b', caseSensitive: false), null),
    ];
    for (final (pattern, pri) in priorityPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final matched = match.group(0)!;
        if (matched.length == 2 && matched.startsWith('p')) {
          priority = TaskPriority.values[int.parse(matched[1])];
        } else {
          priority = pri;
        }
        text = text.replaceFirst(RegExp(RegExp.escape(matched), caseSensitive: false), '').trim();
        break;
      }
    }

    final now = DateTime.now();
    DateTime? date;

    final tomorrowMatch = RegExp(r'\btomorrow\b', caseSensitive: false).firstMatch(text);
    if (tomorrowMatch != null) {
      date = now.add(const Duration(days: 1));
      text = text.replaceFirst(tomorrowMatch.group(0)!, '').trim();
    }

    if (date == null) {
      final todayMatch = RegExp(r'\btoday\b', caseSensitive: false).firstMatch(text);
      if (todayMatch != null) {
        date = now;
        text = text.replaceFirst(todayMatch.group(0)!, '').trim();
      }
    }

    if (date == null) {
      final nextWeekMatch = RegExp(r'\bnext week\b', caseSensitive: false).firstMatch(text);
      if (nextWeekMatch != null) {
        date = now.add(const Duration(days: 7));
        text = text.replaceFirst(nextWeekMatch.group(0)!, '').trim();
      }
    }

    if (date == null) {
      final weekdays = {
        'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
        'friday': 5, 'saturday': 6, 'sunday': 7,
      };
      for (final entry in weekdays.entries) {
        final pattern = RegExp(r'\b(next )?' + entry.key + r'\b', caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null) {
          final isNext = match.group(1) != null;
          int diff = entry.value - now.weekday;
          if (diff <= 0) diff += 7;
          if (isNext) diff += 7;
          date = DateTime(now.year, now.month, now.day).add(Duration(days: diff));
          text = text.replaceFirst(match.group(0)!, '').trim();
          break;
        }
      }
    }

    if (date != null) {
      final timeMatch = RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b', caseSensitive: false).firstMatch(text);
      if (timeMatch != null) {
        int hour = int.parse(timeMatch.group(1)!);
        final minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
        final ampm = timeMatch.group(3);
        if (ampm != null) {
          final isPm = ampm.toLowerCase() == 'pm';
          if (isPm && hour != 12) hour += 12;
          if (!isPm && hour == 12) hour = 0;
        }
        date = DateTime(date.year, date.month, date.day, hour, minute);
        text = text.replaceFirst(timeMatch.group(0)!, '').trim();
      } else {
        date = DateTime(date.year, date.month, date.day, 9, 0);
      }
    }

    return (title: text.isEmpty ? raw.trim() : text, scheduledAt: date, priority: priority);
  }

  Future<void> _quickAddTask() async {
    final raw = _quickAddController.text.trim();
    if (raw.isEmpty) return;

    final categories = ref.read(allCategoriesProvider);
    if (categories.isEmpty) return;

    final parsed = _parseQuickAdd(raw);
    final user = widget.user;
    final task = Task(
      id: FirebaseFirestore.instance.collection('tasks').doc().id,
      userId: user.uid,
      title: parsed.title,
      category: categories.first,
      priority: parsed.priority ?? TaskPriority.none,
      order: DateTime.now().millisecondsSinceEpoch.toDouble(),
      scheduledAt: parsed.scheduledAt ?? DateTime.now(),
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(taskServiceProvider).createTask(task);
      _quickAddController.clear();
      unawaited(HapticFeedback.lightImpact());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create task: $e')),
      );
    }
  }

  Future<void> _batchComplete() async {
    final ids = ref.read(dashboardProvider).selectedTaskIds;
    try {
      for (final id in ids) {
        final doc = await FirebaseFirestore.instance.collection('tasks').doc(id).get();
        if (doc.exists) {
          final t = Task.fromMap(doc.data()!, doc.id);
          await ref.read(taskServiceProvider).updateTask(
            t.copyWith(status: TaskStatus.fulfilled, completedAt: DateTime.now()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error completing tasks: $e');
    }
    ref.read(dashboardProvider.notifier).clearSelection();
  }

  Future<void> _batchDelete() async {
    final ids = ref.read(dashboardProvider).selectedTaskIds;
    try {
      for (final id in ids) {
        await ref.read(taskServiceProvider).deleteTask(id, widget.user.uid);
      }
    } catch (e) {
      debugPrint('Error deleting tasks: $e');
    }
    ref.read(dashboardProvider.notifier).clearSelection();
  }

  void _batchDeleteConfirmed() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete tasks?'),
        content: Text('Delete ${ref.read(dashboardProvider).selectedTaskIds.length} task(s)?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(ctx);
              _batchDelete();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dashboardProvider.select((state) => state.celebrationTrigger), (previous, next) {
      if (next > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task completed!'), duration: Duration(seconds: 2)),
        );
      }
    });

    ref.listen(lastSyncErrorProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            content: Text(next),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ref.read(lastSyncErrorProvider.notifier).setError(null);
              },
            ),
          ),
        );
      }
    });

    final dashboardState = ref.watch(dashboardProvider);
    final selectedIndex = dashboardState.tabIndex;
    final selectionMode = dashboardState.selectionMode;
    final selectedCount = dashboardState.selectedTaskIds.length;
    final userAsync = ref.watch(userStreamProvider(widget.user.uid));
    
    final displayUser = userAsync.value ?? widget.user;
    final controller = ref.read(dashboardProvider.notifier);
    final gradientColors = AppTheme.gradientColors(context);

    return Scaffold(
      body: Stack(
        children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors.primary,
                    gradientColors.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 50,
                bottom: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHeader(
                    displayUser: displayUser,
                  ),

                  if (dashboardState.viewMode == ViewMode.list) const SizedBox(height: 8),
                  if (dashboardState.viewMode == ViewMode.list)
                    _LabelFilterRow(
                      userId: displayUser.uid,
                      labelFilterId: _labelFilterId,
                      onLabelSelected: (id) => setState(() => _labelFilterId = id),
                      onClearFilter: () => setState(() => _labelFilterId = null),
                    ),
                  if (dashboardState.viewMode == ViewMode.list) const SizedBox(height: 8),
                  
                  if (dashboardState.viewMode == ViewMode.list)
                    Consumer(
                      builder: (context, ref, child) {
                        final countsAsync = ref.watch(taskCountsProvider(displayUser.uid));
                        final counts = countsAsync.value ?? {
                          TaskStatus.undone: 0,
                          TaskStatus.inProgress: 0,
                          TaskStatus.fulfilled: 0,
                        };
                        return TaskStatusFilter(
                          selectedIndex: selectedIndex,
                          undoneCount: counts[TaskStatus.undone] ?? 0,
                          inProgressCount: counts[TaskStatus.inProgress] ?? 0,
                          fulfilledCount: counts[TaskStatus.fulfilled] ?? 0,
                          onTabSelected: (index) {
                            ref.read(dashboardProvider.notifier).setTabIndex(index);
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: dashboardState.viewMode == ViewMode.kanban
                        ? KanbanView(
                            userId: displayUser.uid,
                            userInitial: displayUser.initial,
                          )
                        : TaskListView(
                            userId: displayUser.uid,
                            selectedIndex: selectedIndex,
                            userInitial: displayUser.initial,
                            labelFilterId: _labelFilterId,
                          ),
                  ),

                  const SizedBox(height: 6),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _ViewModeChip(
                            icon: Icons.calendar_month_outlined,
                            label: 'Schedule',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SchedulePage(user: displayUser),
                                ),
                              );
                            },
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _ViewModeChip(
                              icon: dashboardState.viewMode == ViewMode.kanban
                                  ? Icons.dashboard_outlined
                                  : Icons.view_list_outlined,
                              label: dashboardState.viewMode == ViewMode.kanban
                                  ? 'List'
                                  : 'Kanban',
                              onTap: () => ref.read(dashboardProvider.notifier).toggleViewMode(),
                            ),
                          ),
                          if (dashboardState.viewMode == ViewMode.list)
                            Align(
                              alignment: Alignment.centerRight,
                              child: _ViewModeChip(
                                icon: _groupIcon(dashboardState.groupBy),
                                label: _groupLabel(dashboardState.groupBy),
                                onTap: () {
                                  final currentGroup = dashboardState.groupBy;
                                  final groupOptions = GroupBy.values;
                                  showCupertinoModalPopup(
                                    context: context,
                                    builder: (ctx) => CupertinoActionSheet(
                                      title: const Text('Group by'),
                                      actions: [
                                        for (final g in groupOptions)
                                          CupertinoActionSheetAction(
                                            isDefaultAction: g == currentGroup,
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              ref.read(dashboardProvider.notifier).setGroupBy(g);
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _groupIcon(g),
                                                  size: 18,
                                                  color: g == currentGroup
                                                      ? Theme.of(context).colorScheme.primary
                                                      : null,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(_groupLabel(g)),
                                              ],
                                            ),
                                          ),
                                      ],
                                      cancelButton: CupertinoActionSheetAction(
                                        isDestructiveAction: true,
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _quickAddController,
                            focusNode: dashboardState.searchMode ? _searchFocusNode : null,
                            placeholder: dashboardState.searchMode ? 'Search tasks...' : 'Quick add...',
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            onChanged: dashboardState.searchMode
                                ? (val) => ref.read(dashboardProvider.notifier).updateSearchQuery(val)
                                : null,
                            onSubmitted: dashboardState.searchMode ? null : (_) => _quickAddTask(),
                            suffix: dashboardState.searchMode && _quickAddController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _quickAddController.clear();
                                      ref.read(dashboardProvider.notifier).updateSearchQuery('');
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final notifier = ref.read(dashboardProvider.notifier);
                            if (dashboardState.searchMode) {
                              _quickAddController.clear();
                              _searchFocusNode.unfocus();
                              notifier.setSearchMode(false);
                            } else {
                              notifier.setSearchMode(true);
                              _searchFocusNode.requestFocus();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: dashboardState.searchMode
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              dashboardState.searchMode ? Icons.search_off : Icons.search,
                              color: dashboardState.searchMode
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final currentSort = dashboardState.sortBy;
                            final sortOptions = SortBy.values;
                            showCupertinoModalPopup(
                              context: context,
                              builder: (ctx) => CupertinoActionSheet(
                                title: const Text('Sort by'),
                                actions: [
                                  for (final sort in sortOptions)
                                    CupertinoActionSheetAction(
                                      isDefaultAction: sort == currentSort,
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        ref.read(dashboardProvider.notifier).setSortBy(sort);
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _sortIcon(sort) ?? Icons.swap_vert,
                                            size: 18,
                                            color: sort == currentSort
                                                ? Theme.of(context).colorScheme.primary
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_sortLabel(sort)),
                                        ],
                                      ),
                                    ),
                                ],
                                cancelButton: CupertinoActionSheetAction(
                                  isDestructiveAction: true,
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _sortIcon(dashboardState.sortBy) ?? Icons.swap_vert,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (dashboardState.searchMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _quickAddController.clear();
                            _searchFocusNode.unfocus();
                            ref.read(dashboardProvider.notifier).setSearchMode(false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            foregroundColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                            elevation: 6,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close, size: 28),
                              const SizedBox(width: 10),
                              Text(
                                'Cancel search',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (!selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _showAddTaskChoice();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            foregroundColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                            elevation: 6,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, size: 28),
                              const SizedBox(width: 10),
                              Text(
                                'Add a New Task',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const _SyncSuccessOverlay(),
        ],
      ),

      bottomNavigationBar: selectionMode
          ? BottomAppBar(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Consumer(
                  builder: (context, ref, child) {
                    final tasksAsync = ref.watch(tasksStreamProvider(displayUser.uid));
                    final allTasks = tasksAsync.value ?? [];
                    final query = dashboardState.searchQuery.toLowerCase();
                    final smartFilter = dashboardState.smartFilter;
                    final visibleTaskIds = allTasks
                        .where((t) => t.status.index == selectedIndex && !t.isArchived)
                        .where((t) {
                          final matchesSearch = query.isEmpty ||
                              t.title.toLowerCase().contains(query) ||
                              (t.notes != null && t.notes!.toLowerCase().contains(query));
                          bool matchesSmart = true;
                          if (smartFilter == SmartFilter.overdue) matchesSmart = t.deadline != null && t.deadline!.isBefore(DateTime.now());
                          return matchesSearch && matchesSmart;
                        })
                        .map((t) => t.id)
                        .toList();
                    final allVisibleSelected = visibleTaskIds.isNotEmpty &&
                        visibleTaskIds.every((id) => dashboardState.selectedTaskIds.contains(id));
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: Icon(allVisibleSelected ? Icons.deselect : Icons.select_all),
                          tooltip: allVisibleSelected ? 'Deselect all' : 'Select all',
                          onPressed: () {
                            if (allVisibleSelected) {
                              controller.clearSelection();
                              controller.toggleSelectionMode();
                            } else {
                              controller.selectAll(visibleTaskIds);
                            }
                          },
                        ),
                        Text('$selectedCount selected', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.check),
                          tooltip: 'Mark done',
                          onPressed: selectedCount > 0 ? _batchComplete : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: selectedCount > 0 ? _batchDeleteConfirmed : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel',
                          onPressed: () => controller.clearSelection(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }

  static IconData? _sortIcon(SortBy sortBy) => switch (sortBy) {
        SortBy.order => null,
        SortBy.deadline => Icons.event,
        SortBy.priority => Icons.flag,
        SortBy.created => Icons.add_circle_outline,
      };

  static String _sortLabel(SortBy sortBy) => switch (sortBy) {
        SortBy.order => 'Manual',
        SortBy.deadline => 'Deadline',
        SortBy.priority => 'Priority',
        SortBy.created => 'Created',
      };

  static IconData _groupIcon(GroupBy groupBy) => switch (groupBy) {
        GroupBy.none => Icons.view_headline,
        GroupBy.category => Icons.category,
        GroupBy.priority => Icons.flag,
        GroupBy.section => Icons.view_column,
      };

  static String _groupLabel(GroupBy groupBy) => switch (groupBy) {
        GroupBy.none => 'No group',
        GroupBy.category => 'Category',
        GroupBy.priority => 'Priority',
        GroupBy.section => 'Section',
      };
}

class _LabelFilterRow extends ConsumerWidget {
  final String userId;
  final String? labelFilterId;
  final ValueChanged<String?> onLabelSelected;
  final VoidCallback onClearFilter;

  const _LabelFilterRow({
    required this.userId,
    required this.labelFilterId,
    required this.onLabelSelected,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(userLabelsProvider(userId));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: labelsAsync.when(
        data: (labels) {
          final selectedLabel = labelFilterId != null
              ? labels.where((l) => l.id == labelFilterId).firstOrNull
              : null;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                if (selectedLabel != null)
                  GestureDetector(
                    onTap: onClearFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Color(selectedLabel.color).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(selectedLabel.color).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: Color(selectedLabel.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            selectedLabel.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(selectedLabel.color),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.close, size: 12, color: Color(selectedLabel.color)),
                        ],
                      ),
                    ),
                  ),
                _buildLabelsButton(context, ref, labels),
              ],
            ),
          );
        },
        loading: () => _buildSingleLabelsButton(context, ref, const []),
        error: (_, __) => _buildSingleLabelsButton(context, ref, const []),
      ),
    );
  }

  Widget _buildLabelsButton(BuildContext context, WidgetRef ref, List<Label> labels) {
    return GestureDetector(
      onTap: () => _showLabelPicker(context, ref, labels),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 12, color: Colors.white60),
            const SizedBox(width: 3),
            Text(
              'Labels',
              style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleLabelsButton(BuildContext context, WidgetRef ref, List<Label> labels) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _buildLabelsButton(context, ref, labels),
        ],
      ),
    );
  }

  void _showCreateLabelDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Label name',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.red, Colors.orange, Colors.amber, Colors.yellow,
                  Colors.green, Colors.teal, Colors.cyan, Colors.blue,
                  Colors.indigo, Colors.purple, Colors.pink, Colors.brown,
                ].map((c) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selectedColor == c
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final id = ref.read(labelServiceProvider).generateId(userId);
                await ref.read(labelServiceProvider).createLabel(Label(
                  id: id,
                  name: nameController.text.trim(),
                  color: selectedColor.toARGB32(),
                  userId: userId,
                ));
                ref.invalidate(userLabelsProvider(userId));
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLabelPicker(BuildContext context, WidgetRef ref, List<Label> labels) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Filter by label', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              ),
              if (labels.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No labels yet.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                ),
              for (final label in labels)
                ListTile(
                  leading: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: Color(label.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(label.name, style: TextStyle(color: cs.onSurface)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (labelFilterId == label.id)
                        Icon(Icons.check, color: cs.primary),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Label'),
                              content: Text('Delete "${label.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(labelServiceProvider).deleteLabel(userId, label.id);
                            ref.invalidate(userLabelsProvider(userId));
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onLabelSelected(label.id);
                  },
                ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.add, color: cs.onSurface.withValues(alpha: 0.6)),
                title: Text('Create new label', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateLabelDialog(context, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncSuccessOverlay extends ConsumerStatefulWidget {
  const _SyncSuccessOverlay();

  @override
  ConsumerState<_SyncSuccessOverlay> createState() => _SyncSuccessOverlayState();
}

class _SyncSuccessOverlayState extends ConsumerState<_SyncSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleIn;
  late Animation<double> _fadeIn;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _animate() {
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _controller.reverse();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(showSuccessIndicatorProvider, (prev, next) {
      if (next == true && prev == false) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) _animate();
        });
      }
      if (next == false) {
        _debounceTimer?.cancel();
        _controller.reverse();
      }
    });

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0 && !_controller.isAnimating) {
          return const SizedBox.shrink();
        }
        return Positioned(
          bottom: 180,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: _fadeIn.value,
                child: Transform.scale(
                  scale: _scaleIn.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A3E)
                          : Colors.black87,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.greenAccent, size: 22),
                        SizedBox(width: 8),
                        Text('Synced', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ViewModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ViewModeChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


