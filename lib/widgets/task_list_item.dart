import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:to_do_app/models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/services/task_service.dart';

import 'package:flutter/services.dart';
import 'package:to_do_app/widgets/add_task_sheet.dart';
import 'package:to_do_app/screens/focus_mode_screen.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/unified_subtask_provider.dart';
import 'package:to_do_app/services/subtask_service.dart';
import 'package:to_do_app/services/group_service.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/models/subclasses/group_task.dart';
import 'package:to_do_app/providers/group_members_cache_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/widgets/add_task/subtask_create_sheet.dart';

class TaskListItem extends ConsumerStatefulWidget {
  final Task task;
  final int selectedIndex;
  final String userInitial;
  final bool compact;
  final bool showSubtasks;
  final void Function(Task task, Offset globalPos, Size cardSize)? onPortalFulfill;

  const TaskListItem({
    super.key,
    required this.task,
    this.selectedIndex = 0,
    this.userInitial = '?',
    this.compact = false,
    this.showSubtasks = true,
    this.onPortalFulfill,
  });

  @override
  ConsumerState<TaskListItem> createState() => _TaskListItemState();
}

class _TaskListItemState extends ConsumerState<TaskListItem> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _slideController;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;
  double _dragX = 0.0;
  bool _subtaskExpanded = false;
  final Set<String> _expandedSubtaskIds = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    
    _sizeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));

    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragX = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() => _dragX += details.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final width = context.size?.width ?? 400;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragX.abs() > width * 0.38 || (velocity.abs() > 500 && _dragX.sign == velocity.sign)) {
      final targetX = _dragX.sign * (width + 200);
      final flyTween = Tween<double>(begin: _dragX, end: targetX);
      final flyAnim = flyTween.animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
      );
      _slideController.addListener(() {
        if (!mounted) return;
        setState(() => _dragX = flyAnim.value);
      });
      _slideController.addStatusListener(_onFlyOffComplete);
      _slideController.forward();
    } else {
      HapticFeedback.lightImpact();
      final spring = SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 180,
        ratio: 0.3,
      );
      final simulation = SpringSimulation(spring, _dragX, 0, velocity);
      _slideController.addListener(() {
        if (!mounted) return;
        setState(() => _dragX = _slideController.value);
      });
      _slideController.animateWith(simulation);
    }
  }

  void _onFlyOffComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _slideController.removeStatusListener(_onFlyOffComplete);
    if (!mounted) return;
    if (_dragX < 0) {
      _handleDelete();
    } else {
      _handleToggleStatus();
    }
  }

  void _handleDelete() {
    final taskData = widget.task.toMap();
    final taskId = widget.task.id;
    final userId = widget.task.userId;
    setState(() => _dragX = 0);
    _routeDeleteTask(taskId, userId).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final task = Task.fromMap(taskData, taskId);
              try {
                await ref.read(taskServiceProvider).createTask(task);
              } catch (e) {
                debugPrint('Error restoring task: $e');
              }
            },
          ),
        ),
      );
    }).catchError((e) {
      debugPrint('Error deleting task: $e');
    });
  }

  void _handleToggleStatus() {
    final previousStatus = widget.task.status;
    final previousCompletedAt = widget.task.completedAt;
    final targetStatus = previousStatus == TaskStatus.fulfilled
        ? TaskStatus.undone
        : TaskStatus.fulfilled;
    setState(() => _dragX = 0);
    _updateStatus(targetStatus).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            targetStatus == TaskStatus.fulfilled
                ? 'Task completed'
                : 'Task marked as undone',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final restored = widget.task.copyWith(
                status: previousStatus,
                completedAt: previousCompletedAt,
              );
              try {
                await _routeUpdateTask(restored);
              } catch (e) {
                debugPrint('Error undoing status change: $e');
              }
            },
          ),
        ),
      );
    });
  }

  Future<void> _updateStatus(TaskStatus newStatus) async {
    if (widget.task.status == newStatus) return;

    if (newStatus == TaskStatus.fulfilled) {
      unawaited(HapticFeedback.mediumImpact());
      ref.read(dashboardProvider.notifier).triggerCelebration();
    } else {
      unawaited(HapticFeedback.lightImpact());
    }

    await _controller.reverse();
    
    final updatedTask = widget.task.copyWith(
      status: newStatus,
      completedAt: newStatus == TaskStatus.fulfilled ? DateTime.now() : null,
    );

    try {
      await _routeUpdateTask(updatedTask);
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }


  String? _getTimeRemaining() {
    if (widget.task.deadline == null || widget.task.status == TaskStatus.fulfilled) {
      return null;
    }

    final now = DateTime.now();
    final deadline = widget.task.deadline!;
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      final absDiff = difference.abs();
      if (absDiff.inMinutes < 60) {
        return 'Overdue by ${absDiff.inMinutes} minute${absDiff.inMinutes == 1 ? '' : 's'}';
      } else if (absDiff.inHours < 24) {
        return 'Overdue by ${absDiff.inHours} hour${absDiff.inHours == 1 ? '' : 's'}';
      } else {
        final days = absDiff.inDays;
        return 'Overdue by $days day${days == 1 ? '' : 's'}';
      }
    } else {
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} remaining';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} remaining';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} remaining';
      } else {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks week${weeks == 1 ? '' : 's'} remaining';
      }
    }
  }

  void _showPostponeSheet() {
    final options = [
      ('1 hour', const Duration(hours: 1)),
      ('3 hours', const Duration(hours: 3)),
      ('Tomorrow 9am', null),
      ('Tomorrow evening 6pm', null),
      ('Next week', const Duration(days: 7)),
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Postpone until'),
        actions: [
          for (final (label, duration) in options)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!context.mounted) return;
                DateTime newDate;
                if (label.startsWith('Tomorrow')) {
                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                  newDate = DateTime(
                    tomorrow.year, tomorrow.month, tomorrow.day,
                    label.contains('9am') ? 9 : 18,
                  );
                } else {
                  newDate = DateTime.now().add(duration!);
                }
                final updated = widget.task.copyWith(scheduledAt: newDate);
                try {
                  await _routeUpdateTask(updated);
                } catch (e) {
                  debugPrint('Error postponing task: $e');
                }
              },
              child: Text(label),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSubTask() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await showSubtaskCreateSheet(
      context: context,
      taskId: widget.task.id,
      userId: user.uid,
    );
    if (result == null || !mounted) return;

    String id;
    if (_groupId != null) {
      id = ref.read(groupServiceProvider).generateTaskId(_groupId!);
    } else {
      id = ref.read(subTaskServiceProvider).generateId();
    }
    await _routeCreateSubTask(SubTask(
      id: id,
      taskId: result.taskId,
      userId: result.userId,
      title: result.title,
      priority: result.priority,
      deadline: result.deadline,
      notes: result.notes,
      order: result.order,
    ));
  }

  Future<void> _toggleSubTask(SubTask subTask) async {
    try {
      final becomingDone = !subTask.isDone;
      await _routeUpdateSubTask(
        subTask.copyWith(isDone: becomingDone),
      );

      if (becomingDone) {
        TaskStatus? target;
        if (widget.task.status == TaskStatus.undone) {
          target = TaskStatus.inProgress;
        }
        if (await _allSubtasksDone()) {
          target = TaskStatus.fulfilled;
        }
        if (target == null) return;

        if (target == TaskStatus.fulfilled) {
          final renderBox = context.findRenderObject() as RenderBox?;
          final pos = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
          final size = renderBox?.size ?? Size.zero;
          widget.onPortalFulfill?.call(widget.task, pos, size);
        }

        if (!mounted) return;
        await _controller.reverse();
        if (!mounted) return;
        await _routeUpdateTask(
          widget.task.copyWith(
            status: target,
            completedAt: target == TaskStatus.fulfilled ? DateTime.now() : null,
          ),
        );
        if (target != TaskStatus.fulfilled && mounted) {
          await _controller.forward();
        }
      }
    } catch (e) {
      debugPrint('Error toggling subtask: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update subtask')),
        );
      }
    }
  }

  String? get _groupId => widget.task.groupId;

  Future<void> _routeUpdateTask(Task task) async {
    if (_groupId != null) {
      await ref.read(groupServiceProvider).updateTask(task.toGroupTask());
    } else {
      await ref.read(taskServiceProvider).updateTask(task);
    }
  }

  Future<void> _routeDeleteTask(String taskId, String userId) async {
    if (_groupId != null) {
      await ref.read(groupServiceProvider).deleteTask(_groupId!, taskId);
    } else {
      await ref.read(taskServiceProvider).deleteTask(taskId, userId);
    }
  }

  Future<void> _routeUpdateSubTask(SubTask subTask) async {
    if (_groupId != null) {
      final gst = GroupSubTask.fromSubTask(subTask, groupTaskId: subTask.taskId);
      await ref.read(groupServiceProvider).updateSubTask(gst, _groupId!);
    } else {
      await ref.read(subTaskServiceProvider).updateSubTask(subTask);
    }
  }

  Future<void> _routeCreateSubTask(SubTask subTask) async {
    if (_groupId != null) {
      final gst = GroupSubTask.fromSubTask(subTask, groupTaskId: subTask.taskId);
      await ref.read(groupServiceProvider).createSubTask(gst, _groupId!);
    } else {
      await ref.read(subTaskServiceProvider).createSubTask(subTask);
    }
  }

  Future<void> _routeDeleteSubTask(SubTask subTask) async {
    if (_groupId != null) {
      await ref.read(groupServiceProvider).deleteSubTask(_groupId!, subTask.taskId, subTask.id);
    } else {
      await ref.read(subTaskServiceProvider).deleteSubTask(subTask.id);
    }
  }

  Future<bool> _allSubtasksDone() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;
    try {
      if (_groupId != null) {
        final query = await FirebaseFirestore.instance
            .collection('groups')
            .doc(_groupId)
            .collection('tasks')
            .doc(widget.task.id)
            .collection('subtasks')
            .get();
        if (query.docs.isEmpty) return false;
        return query.docs.every(
          (doc) => (doc.data()['isDone'] as bool?) ?? false,
        );
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('subtasks')
          .where('taskId', isEqualTo: widget.task.id)
          .where('userId', isEqualTo: userId)
          .get();
      if (snapshot.docs.isEmpty) return false;
      return snapshot.docs.every(
        (doc) => (doc.data()['isDone'] as bool?) ?? false,
      );
    } catch (e) {
      debugPrint('Error checking subtasks: $e');
      return false;
    }
  }

  Future<void> _deleteSubTask(SubTask subTask) async {
    await _routeDeleteSubTask(subTask);
  }

  Widget _buildSubtaskSection() {
    final subTasksAsync = ref.watch(unifiedSubTasksProvider(SubTaskQuery(
      taskId: widget.task.id,
      groupId: _groupId,
    )));

    return subTasksAsync.when(
      data: (subTasks) {
        final doneCount = subTasks.where((s) => s.isDone).length;
        final color = Color(widget.task.category.color);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 16),
            GestureDetector(
              onTap: () => setState(() => _subtaskExpanded = !_subtaskExpanded),
              child: Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Row(
                  children: [
                    Icon(
                      _subtaskExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: color.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Subtasks  $doneCount/${subTasks.length}',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (!_subtaskExpanded)
                      Icon(Icons.add_circle_outline, size: 16, color: color.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
            if (_subtaskExpanded) ...[
              ...subTasks.map((subTask) {
                final isExpanded = _expandedSubtaskIds.contains(subTask.id);
                return Padding(
                  key: ValueKey(subTask.id),
                  padding: const EdgeInsets.only(left: 52, top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleSubTask(subTask),
                            child: Icon(
                              subTask.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 18,
                              color: subTask.isDone ? Colors.green : color.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              subTask.title,
                              style: TextStyle(
                                color: color.withValues(alpha: subTask.isDone ? 0.5 : 0.9),
                                decoration: subTask.isDone ? TextDecoration.lineThrough : null,
                                decorationColor: color.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              if (isExpanded) {
                                _expandedSubtaskIds.remove(subTask.id);
                              } else {
                                _expandedSubtaskIds.add(subTask.id);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                isExpanded ? Icons.expand_less : Icons.more_horiz,
                                size: 16,
                                color: color.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteSubTask(subTask),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 14, color: Colors.red.withValues(alpha: 0.6)),
                            ),
                          ),
                        ],
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 4),
                        _buildSubTaskMeta(subTask),
                      ],
                    ],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 8),
                child: GestureDetector(
                  onTap: _addSubTask,
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 16, color: color.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        'Add subtask',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(left: 52),
        child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 11)),
      ),
    );
  }

  Widget _buildSubTaskMeta(SubTask subTask) {
    final color = Color(widget.task.category.color);
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        if (subTask.priority != TaskPriority.none)
          _chip(
            label: subTask.priority.displayName,
            color: _priorityColor(subTask.priority),
            onTap: () => _cyclePriority(subTask),
          )
        else
          _chip(label: '+ priority', color: color.withValues(alpha: 0.3), onTap: () => _cyclePriority(subTask)),
        if (subTask.scheduledAt != null || subTask.deadline != null)
          _chip(
            label: _formatDate(subTask.deadline ?? subTask.scheduledAt!),
            color: color.withValues(alpha: 0.5),
            onTap: () => _showDateSetter(subTask),
          )
        else
          _chip(label: '+ date', color: color.withValues(alpha: 0.3), onTap: () => _showDateSetter(subTask)),
        if (subTask.notes != null && subTask.notes!.isNotEmpty)
          _chip(
            label: subTask.notes!.length > 18 ? '${subTask.notes!.substring(0, 18)}…' : subTask.notes!,
            color: color.withValues(alpha: 0.5),
            onTap: () => _editNotes(subTask),
          )
        else
          _chip(label: '+ notes', color: color.withValues(alpha: 0.3), onTap: () => _editNotes(subTask)),
      ],
    );
  }

  Widget _chip({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low: return Colors.amber;
      case TaskPriority.medium: return Colors.orange;
      case TaskPriority.high: return Colors.red;
      case TaskPriority.none: return Colors.grey;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 0 && diff <= 7) return '${dt.month}/${dt.day}';
    return '${dt.month}/${dt.day}';
  }

  void _cyclePriority(SubTask subTask) {
    final values = TaskPriority.values;
    final next = values[(subTask.priority.index + 1) % values.length];
    _routeUpdateSubTask(subTask.copyWith(priority: next));
  }

  void _showDateSetter(SubTask subTask) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 260,
        color: CupertinoTheme.of(context).barBackgroundColor,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Clear'),
                  onPressed: () {
                    Navigator.pop(context);
                    _routeUpdateSubTask(subTask.copyWith(
                      scheduledAt: null,
                      deadline: null,
                    ));
                  },
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: subTask.deadline ?? subTask.scheduledAt ?? DateTime.now(),
                onDateTimeChanged: (dt) {
                  _routeUpdateSubTask(subTask.copyWith(deadline: dt));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editNotes(SubTask subTask) {
    final controller = TextEditingController(text: subTask.notes ?? '');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Notes'),
        content: CupertinoTextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.lightBackgroundGray),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: const Text('Save'),
            onPressed: () {
              _routeUpdateSubTask(
                subTask.copyWith(notes: controller.text.isEmpty ? null : controller.text),
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSubtaskSection() {
    final subTasksAsync = ref.watch(unifiedSubTasksProvider(SubTaskQuery(
      taskId: widget.task.id,
      groupId: _groupId,
    )));
    final color = Color(widget.task.category.color);

    return subTasksAsync.when(
      data: (subTasks) {
        final doneCount = subTasks.where((s) => s.isDone).length;
        final showEmptyAdd = subTasks.isEmpty && !_subtaskExpanded;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () => setState(() => _subtaskExpanded = !_subtaskExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    if (showEmptyAdd)
                      const SizedBox(width: 14)
                    else
                      Icon(
                        _subtaskExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 12,
                        color: color.withValues(alpha: 0.5),
                      ),
                    const SizedBox(width: 3),
                    if (showEmptyAdd)
                      Icon(Icons.add_circle_outline, size: 12, color: color.withValues(alpha: 0.45))
                    else ...[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: subTasks.isEmpty ? 0 : doneCount / subTasks.length,
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              doneCount == subTasks.length
                                  ? Colors.green
                                  : color.withValues(alpha: 0.55),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$doneCount/${subTasks.length}',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.55),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (showEmptyAdd)
                      Text(
                        ' Subtask',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.45),
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_subtaskExpanded) ...[
              const SizedBox(height: 4),
              ...subTasks.take(3).map((subTask) => Padding(
                key: ValueKey(subTask.id),
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleSubTask(subTask),
                      child: Icon(
                        subTask.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 13,
                        color: subTask.isDone
                            ? Colors.green
                            : color.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (subTask.priority != TaskPriority.none)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: _priorityColor(subTask.priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        subTask.title,
                        style: TextStyle(
                          color: color.withValues(alpha: subTask.isDone ? 0.35 : 0.75),
                          decoration: subTask.isDone ? TextDecoration.lineThrough : null,
                          decorationColor: color.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _deleteSubTask(subTask),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 11, color: Colors.red.withValues(alpha: 0.45)),
                      ),
                    ),
                  ],
                ),
              )),
              if (subTasks.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '+${subTasks.length - 3} more',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.35),
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _addSubTask,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 11, color: color.withValues(alpha: 0.35)),
                      const SizedBox(width: 3),
                      Text(
                        'Add subtask',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.35),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectionMode = ref.watch(dashboardProvider.select((s) => s.selectionMode));
    final isSelected = ref.watch(dashboardProvider.select((s) => s.selectedTaskIds.contains(widget.task.id)));
    final remaining = _getTimeRemaining();

    if (selectionMode) {
      return _buildSelectionItem(isSelected);
    }

    if (widget.compact) {
      return _buildCompactCard();
    }

    final showDeleteBg = _dragX < 0;
    final absDrag = _dragX.abs();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizeTransition(
        sizeFactor: _sizeAnimation,
        child: GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (absDrag > 10)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 6,
                  bottom: 6,
                  child: AnimatedOpacity(
                    opacity: absDrag > 10 ? (absDrag / 200).clamp(0.0, 1.0) : 0.0,
                    duration: Duration.zero,
                    child: Container(
                      decoration: BoxDecoration(
                        color: showDeleteBg
                            ? Colors.red
                            : widget.task.status == TaskStatus.fulfilled
                                ? Colors.amber
                                : Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: showDeleteBg ? Alignment.centerRight : Alignment.centerLeft,
                      padding: EdgeInsets.only(
                        left: showDeleteBg ? 0 : 20,
                        right: showDeleteBg ? 20 : 0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            showDeleteBg
                                ? Icons.delete
                                : widget.task.status == TaskStatus.fulfilled
                                    ? Icons.undo
                                    : Icons.check_circle,
                            color: Colors.white,
                            size: 28,
                          ),
                          Text(
                            showDeleteBg
                                ? 'Delete'
                                : widget.task.status == TaskStatus.fulfilled
                                    ? 'Undo'
                                    : 'Done',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Transform(
                transform: Matrix4.identity()
                  // ignore: deprecated_member_use
                  ..translate(_dragX, 0.0, 0.0)
                  ..rotateZ(_dragX * 0.0002),
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {
                      showCupertinoDialog(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('Update Task'),
                          content: Text('"${widget.task.title}"'),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () {
                                Navigator.pop(ctx);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => AddTaskSheet(existingTask: widget.task),
                                );
                              },
                              child: const Text('Edit'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FocusModeScreen(task: widget.task),
                                  ),
                                );
                              },
                              child: const Text('Focus'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showPostponeSheet();
                              },
                              child: const Text('Postpone'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                if (!context.mounted) return;
                                final updated = widget.task.copyWith(pinned: !widget.task.pinned);
                                await _routeUpdateTask(updated);
                              },
                              child: Text(widget.task.pinned ? 'Unpin' : 'Pin'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                if (!context.mounted) return;
                                await _updateStatus(TaskStatus.fulfilled);
                              },
                              child: const Text('Done'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                if (!context.mounted) return;
                                await _updateStatus(TaskStatus.undone);
                              },
                              child: const Text('Not Done'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08), 
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              widget.task.groupId != null
                                  ? _GroupAvatarLookup(groupId: widget.task.groupId!, color: Color(widget.task.category.color))
                                  : GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(dashboardProvider.notifier).toggleSelectionMode();
                                  ref.read(dashboardProvider.notifier).toggleTaskSelection(widget.task.id);
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Color(widget.task.category.color).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(widget.task.category.color),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.userInitial,
                                      style: TextStyle(
                                        color: Color(widget.task.category.color),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.task.title,
                                      style: TextStyle(
                                        color: Color(widget.task.category.color),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (remaining != null)
                                      Text(
                                        remaining,
                                        style: TextStyle(
                                          color: widget.task.deadline != null && 
                                                 widget.task.deadline!.isBefore(DateTime.now())
                                              ? Colors.red.shade900
                                              : Colors.red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (widget.task.notes != null)
                                      Text(
                                        widget.task.notes!,
                                        style: TextStyle(
                                          color: Color(widget.task.category.color).withValues(alpha: 0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showPostponeSheet();
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (widget.task.scheduledAt != null)
                                      Text(
                                        '${widget.task.scheduledAt!.hour.toString().padLeft(2, '0')}:${widget.task.scheduledAt!.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.white38
                                              : Colors.black54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        widget.task.category.name,
                                      style: TextStyle(
                                        color: Color(widget.task.category.color),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _buildSubtaskSection(),
                        ],
                      ),
                    ),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    final color = Color(widget.task.category.color);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizeTransition(
        sizeFactor: _sizeAnimation,
        child: GestureDetector(
      onTap: () {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Update Task'),
            content: Text('"${widget.task.title}"'),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddTaskSheet(existingTask: widget.task),
                  );
                },
                child: const Text('Edit'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FocusModeScreen(task: widget.task),
                    ),
                  );
                },
                child: const Text('Focus'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showPostponeSheet();
                },
                child: const Text('Postpone'),
              ),
              CupertinoDialogAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  final updated = widget.task.copyWith(pinned: !widget.task.pinned);
                  await _routeUpdateTask(updated);
                },
                child: Text(widget.task.pinned ? 'Unpin' : 'Pin'),
              ),
              CupertinoDialogAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await _updateStatus(TaskStatus.fulfilled);
                },
                child: const Text('Done'),
              ),
              CupertinoDialogAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await _updateStatus(TaskStatus.undone);
                },
                child: const Text('Not Done'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.task.title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (widget.task.notes != null && widget.task.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  widget.task.notes!,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (widget.task.deadline != null || widget.task.scheduledAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (widget.task.deadline != null)
                      Icon(Icons.access_time, size: 10, color: color.withValues(alpha: 0.5)),
                    if (widget.task.deadline != null) const SizedBox(width: 2),
                    if (widget.task.deadline != null)
                      Text(
                        '${widget.task.deadline!.day}/${widget.task.deadline!.month}',
                        style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.5)),
                      ),
                    if (widget.task.scheduledAt != null && widget.task.deadline != null)
                      const SizedBox(width: 4),
                    if (widget.task.scheduledAt != null)
                      Text(
                        '${widget.task.scheduledAt!.hour.toString().padLeft(2, '0')}:${widget.task.scheduledAt!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.5)),
                      ),
                    const Spacer(),
                    Text(
                      widget.task.category.name,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.showSubtasks) _buildCompactSubtaskSection(),
          ],
        ),
      ),
    ),
  ),
);

}

  Widget _buildSelectionItem(bool isSelected) {
    return GestureDetector(
      onTap: () => ref.read(dashboardProvider.notifier).toggleTaskSelection(widget.task.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => ref.read(dashboardProvider.notifier).toggleTaskSelection(widget.task.id),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.task.title,
                style: TextStyle(
                  color: Color(widget.task.category.color),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupAvatarLookup extends ConsumerWidget {
  final String groupId;
  final Color color;

  const _GroupAvatarLookup({required this.groupId, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cacheAsync = ref.watch(groupMembersCacheProvider(userId));
    return cacheAsync.when(
      data: (cache) {
        final members = cache[groupId] ?? [];
        if (members.isEmpty) {
          return SizedBox(
            width: 40, height: 40,
            child: Center(child: Icon(Icons.group, size: 20, color: color)),
          );
        }
        return _GroupAvatars(members: members, color: color);
      },
      loading: () => SizedBox(
        width: 40, height: 40,
        child: Center(child: Icon(Icons.group, size: 20, color: color)),
      ),
      error: (_, __) => SizedBox(
        width: 40, height: 40,
        child: Center(child: Icon(Icons.group, size: 20, color: color)),
      ),
    );
  }
}

class _GroupAvatars extends StatelessWidget {
  final List<GroupMember> members;
  final Color color;

  const _GroupAvatars({required this.members, required this.color});

  @override
  Widget build(BuildContext context) {
    final display = members.take(4).toList();
    const avatarSize = 24.0;
    const overlap = 8.0;
    final totalWidth = avatarSize + (display.length - 1) * (avatarSize - overlap);

    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(
        children: [
          for (int i = 0; i < display.length; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    display[i].username.isNotEmpty
                        ? display[i].username[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          if (members.length > 4)
            Positioned(
              left: 4 * (avatarSize - overlap),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '+${members.length - 4}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
