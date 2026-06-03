import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/widgets/task_list_view.dart';
import 'package:to_do_app/widgets/kanban_view.dart';
import 'package:to_do_app/widgets/add_task_sheet.dart';
import 'package:to_do_app/widgets/dashboard_header.dart';
import 'package:to_do_app/widgets/task_status_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/user_provider.dart';
import 'package:to_do_app/providers/sync_provider.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:to_do_app/providers/pagination_provider.dart';
import 'package:to_do_app/providers/add_task_provider.dart';
import 'package:to_do_app/providers/categories_provider.dart';
import 'package:to_do_app/providers/smart_filters_provider.dart';
import 'package:to_do_app/services/task_service.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/services/share_service.dart';
import 'package:to_do_app/theme/app_theme.dart';
import 'package:to_do_app/widgets/notification_permission_dialog.dart';
import 'package:to_do_app/widgets/screen_pinning_dialog.dart';
import 'package:to_do_app/widgets/weekly_review_dialog.dart';

class Dashboard extends ConsumerStatefulWidget {
  final User user;
  const Dashboard({super.key, required this.user});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  late ConfettiController _confettiController;
  final _quickAddController = TextEditingController();
  StreamSubscription? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupNotifications());
    WidgetsBinding.instance.addPostFrameCallback((_) => _showScreenPinningDialog());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWeeklyReview());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSharedText());
    _shareSubscription = ShareService.onShared.stream.listen((text) {
      _openAddTaskSheetWithText(text);
    });
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _confettiController.dispose();
    _quickAddController.dispose();
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

  Future<void> _batchArchive() async {
    final ids = ref.read(dashboardProvider).selectedTaskIds;
    try {
      await ref.read(taskServiceProvider).archiveTasks(ids.toList());
    } catch (e) {
      debugPrint('Error archiving tasks: $e');
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
      if (next > 0) {
        _confettiController.play();
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
                bottom: selectionMode ? 70 : 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHeader(
                    displayUser: displayUser,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildSmartChip('All', SmartFilter.all, controller),
                              for (final filter in ref.watch(smartFiltersProvider))
                                _buildSmartChip(_filterLabel(filter), filter, controller),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildFilterSettingsIcon(context),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  if (dashboardState.viewMode != ViewMode.kanban)
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
                            ref.read(taskLimitProvider.notifier).reset();
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
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: CupertinoTextField(
                      controller: _quickAddController,
                      placeholder: 'Quick add...',
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      onSubmitted: (_) => _quickAddTask(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => ref.read(dashboardProvider.notifier).toggleViewMode(),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      dashboardState.viewMode == ViewMode.kanban
                                          ? Icons.view_list_outlined
                                          : Icons.dashboard_outlined,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      dashboardState.viewMode == ViewMode.kanban
                                          ? 'List view'
                                          : 'Kanban view',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: selectionMode
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: SizedBox(
                height: 70,
                width: 400,
                child: FloatingActionButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AddTaskSheet(),
                    );
                  },
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(35),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).brightness == Brightness.dark 
                                 ? Colors.white 
                                 : Theme.of(context).colorScheme.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Add a New Task',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark 
                                   ? Colors.white 
                                   : CupertinoColors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
                          return matchesSearch && _matchesSmartFilter(t, smartFilter);
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
                          icon: const Icon(Icons.archive_outlined),
                          tooltip: 'Archive',
                          onPressed: selectedCount > 0 ? _batchArchive : null,
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

  String _filterLabel(SmartFilter filter) => switch (filter) {
        SmartFilter.today => 'Today',
        SmartFilter.thisWeek => 'Week',
        SmartFilter.overdue => 'Overdue',
        SmartFilter.highPriority => 'High',
        SmartFilter.hasDeadline => 'Has deadline',
        SmartFilter.noDeadline => 'No deadline',
        SmartFilter.thisMonth => 'This month',
        SmartFilter.recurring => 'Recurring',
        SmartFilter.all => 'All',
      };

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

  Widget _buildFilterSettingsIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _showFilterSettings,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.tune, color: cs.primary, size: 16),
      ),
    );
  }

  void _showFilterSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        final enabled = Set<SmartFilter>.from(ref.read(smartFiltersProvider));
        return StatefulBuilder(
          builder: (context, setInnerState) => AlertDialog(
            title: const Text('Quick Filters'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final filter in [
                    SmartFilter.today,
                    SmartFilter.thisWeek,
                    SmartFilter.overdue,
                    SmartFilter.highPriority,
                    SmartFilter.hasDeadline,
                    SmartFilter.noDeadline,
                    SmartFilter.thisMonth,
                    SmartFilter.recurring,
                  ])
                    CheckboxListTile(
                      title: Text(_filterLabel(filter)),
                      value: enabled.contains(filter),
                      dense: true,
                      onChanged: (_) {
                        setInnerState(() {
                          if (enabled.contains(filter)) {
                            enabled.remove(filter);
                          } else {
                            enabled.add(filter);
                          }
                        });
                        ref.read(smartFiltersProvider.notifier).toggle(filter);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmartChip(String label, SmartFilter filter, DashboardNotifier controller) {
    final current = ref.watch(dashboardProvider.select((s) => s.smartFilter));
    final selected = current == filter;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? cs.onPrimary : cs.onSurface)),
        selected: selected,
        selectedColor: cs.primary,
        backgroundColor: cs.surface.withValues(alpha: 0.25),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) => controller.setSmartFilter(filter),
      ),
    );
  }
}
