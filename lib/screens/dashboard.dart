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
import 'package:to_do_app/providers/smart_filters_provider.dart';
import 'package:to_do_app/services/task_service.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/services/share_service.dart';
import 'package:to_do_app/core/smart_filter_utils.dart';
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
                          ),
                  ),

                  const SizedBox(height: 6),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ViewModeChip(
                          icon: dashboardState.viewMode == ViewMode.kanban
                              ? Icons.dashboard_outlined
                              : Icons.view_list_outlined,
                          label: dashboardState.viewMode == ViewMode.kanban
                              ? 'Switch to List'
                              : 'Switch to Kanban',
                          onTap: () => ref.read(dashboardProvider.notifier).toggleViewMode(),
                        ),
                        const SizedBox(width: 8),
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
                        const SizedBox(width: 8),
                        if (dashboardState.viewMode == ViewMode.list)
                          _ViewModeChip(
                            icon: _sortIcon(dashboardState.sortBy) ?? Icons.swap_vert,
                            label: _sortLabel(dashboardState.sortBy),
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
                                            _sortIcon(sort),
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
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 14),
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

                  if (!selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const AddTaskSheet(),
                            );
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

  bool _matchesSmartFilter(Task task, SmartFilter filter) =>
      matchesSmartFilter(task, filter);

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
