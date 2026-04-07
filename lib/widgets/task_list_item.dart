import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/widgets/web_image_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/user_provider.dart';
import 'package:to_do_app/services/task_service.dart';

import 'package:flutter/services.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';

class TaskListItem extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback onComplete;
  final int selectedIndex;

  const TaskListItem({
    super.key,
    required this.task,
    required this.onComplete,
    required this.selectedIndex,
  });

  @override
  ConsumerState<TaskListItem> createState() => _TaskListItemState();
}

class _TaskListItemState extends ConsumerState<TaskListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
    super.dispose();
  }

  Future<void> _updateStatus(TaskStatus newStatus) async {
    if (widget.task.status == newStatus) return;

    if (newStatus == TaskStatus.fulfilled) {
      HapticFeedback.mediumImpact();
      ref.read(celebrationProvider.notifier).trigger();
    } else {
      HapticFeedback.lightImpact();
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
      if (absDiff.inHours < 24) {
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

  @override
  Widget build(BuildContext context) {
    // Easter egg!
    if (widget.task.title == "CrashMe") {
      throw Exception("This is a purposeful test crash!");
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizeTransition(
        sizeFactor: _sizeAnimation,
        axisAlignment: 0.0,
        child: Dismissible(
          key: Key(widget.task.id),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              try {
                await ref.read(taskServiceProvider).deleteTask(widget.task.id);
              } catch (e) {
                debugPrint('Error deleting task: $e');
              }
              return false; 
            } else {
              TaskStatus targetStatus = widget.task.status == TaskStatus.fulfilled
                  ? TaskStatus.undone 
                  : TaskStatus.fulfilled;
                  
              await _updateStatus(targetStatus);
              return false;
            }
          },
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: widget.task.status == TaskStatus.fulfilled
                  ? Colors.amber
                  : Colors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.task.status == TaskStatus.fulfilled
                      ? Icons.undo
                      : Icons.check_circle,
                  color: Colors.white,
                  size: 28,
                ),
                Text(
                  widget.task.status == TaskStatus.fulfilled
                      ? 'Mark as undone'
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
          secondaryBackground: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 28),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          child: GestureDetector(
            onTap: () {
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Update Task'),
                  content: Text('Mark "${widget.task.title}" as:'),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updateStatus(TaskStatus.fulfilled);
                      },
                      child: const Text('Done'),
                    ),
                    CupertinoDialogAction(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updateStatus(TaskStatus.undone);
                      },
                      child: const Text('Not Done'),
                    ),
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context),
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
                    color: Colors.black.withOpacity(0.1), 
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final userAsync = ref.watch(userStreamProvider(widget.task.userId));
                      final pfpUrl = userAsync.value?.profilePictureUrl;

                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(widget.task.category.color).withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(widget.task.category.color),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: pfpUrl != null
                              ? WebImageLoader(url: pfpUrl, size: 40)
                              : Center(
                                  child: Text(
                                    widget.task.title[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Color(widget.task.category.color),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
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
                        if (_getTimeRemaining() != null)
                          Text(
                            _getTimeRemaining()!,
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
                              color: Color(widget.task.category.color).withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}