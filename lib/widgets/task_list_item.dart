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

class TaskListItem extends ConsumerStatefulWidget {
  final Task task;
  final int selectedIndex;
  final String userInitial;
  final bool compact;

  const TaskListItem({
    super.key,
    required this.task,
    this.selectedIndex = 0,
    this.userInitial = '?',
    this.compact = false,
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
    ref.read(taskServiceProvider).deleteTask(taskId, userId).then((_) {
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
                await ref.read(taskServiceProvider).updateTask(restored);
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
      await ref.read(taskServiceProvider).updateTask(updatedTask);
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
                  await ref.read(taskServiceProvider).updateTask(updated);
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
        axisAlignment: 0.0,
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
                                await ref.read(taskServiceProvider).updateTask(updated);
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
                            color: Colors.black.withValues(alpha: 0.1), 
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
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
                                          ? Colors.white54 
                                          : Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Color(widget.task.category.color).withValues(alpha: 0.5),
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
    return GestureDetector(
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
                  await ref.read(taskServiceProvider).updateTask(updated);
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
          ],
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
