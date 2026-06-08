import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/group_task.dart';
import 'package:to_do_app/providers/unified_task_provider.dart';
import 'package:to_do_app/services/task_service.dart';
import 'package:to_do_app/services/group_service.dart';
import 'package:to_do_app/widgets/task_list_item.dart';

Color _saturate(Color c) =>
    HSLColor.fromColor(c).withSaturation(1.0).toColor();

class KanbanView extends ConsumerStatefulWidget {
  final String userId;
  final String userInitial;

  const KanbanView({
    super.key,
    required this.userId,
    this.userInitial = '?',
  });

  @override
  ConsumerState<KanbanView> createState() => _KanbanViewState();
}

class _KanbanViewState extends ConsumerState<KanbanView>
    with SingleTickerProviderStateMixin {
  int? _dragTargetIndex;
  final _doneColumnKey = GlobalKey();

  OverlayEntry? _portalEntry;

  @override
  void dispose() {
    _portalEntry?.remove();
    super.dispose();
  }

  void _startPortal(Task task, Offset sourcePos, Size cardSize) {
    final doneRenderBox =
        _doneColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (doneRenderBox == null) return;
    final doneOffset = doneRenderBox.localToGlobal(Offset.zero);
    final doneSize = doneRenderBox.size;
    final columnHeaderHeight = 36.0;
    final targetX = doneOffset.dx + (doneSize.width - cardSize.width) / 2;
    final targetY = doneOffset.dy + columnHeaderHeight + 8;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => _PortalGhost(
        task: task,
        startPos: sourcePos,
        endPos: Offset(targetX, targetY),
        cardSize: cardSize,
        onDone: () {
          entry?.remove();
          _portalEntry = null;
        },
      ),
    );
    _portalEntry?.remove();
    _portalEntry = entry;
    Overlay.of(context, rootOverlay: false).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(unifiedTasksProvider(widget.userId));

    return tasksAsync.when(
      data: (allTasks) {
        final active = allTasks
            .where((t) => t.status == TaskStatus.undone && !t.isArchived)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        final inProgress = allTasks
            .where((t) => t.status == TaskStatus.inProgress && !t.isArchived)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        final done = allTasks
            .where((t) => t.status == TaskStatus.fulfilled && !t.isArchived)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        final columns = [
          ('Undone', active, TaskStatus.undone),
          ('In Progress', inProgress, TaskStatus.inProgress),
          ('Done', done, TaskStatus.fulfilled),
        ];
        final scheme = Theme.of(context).colorScheme;
        final saturated = _saturate;
        final colors = [
          saturated(scheme.tertiary),
          saturated(scheme.secondary),
          saturated(scheme.primary),
        ];

        return Row(
          children: List.generate(columns.length, (i) {
            final (title, tasks, status) = columns[i];
            return _buildColumn(
                context, title, tasks, colors[i], status, i, ref);
          }),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildColumn(BuildContext context, String title, List<Task> tasks,
      Color color, TaskStatus targetStatus, int index, WidgetRef ref) {
    final isHovered = _dragTargetIndex == index;
    final isDone = targetStatus == TaskStatus.fulfilled;

    return Expanded(
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (details) {
          if (details.data.status == targetStatus) return false;
          setState(() => _dragTargetIndex = index);
          return true;
        },
        onLeave: (_) {
          if (_dragTargetIndex == index) {
            setState(() => _dragTargetIndex = null);
          }
        },
        onAcceptWithDetails: (details) async {
          setState(() => _dragTargetIndex = null);
          final task = details.data;
          if (task.status == targetStatus) return;
          final updated = task.copyWith(
            status: targetStatus,
            completedAt:
                targetStatus == TaskStatus.fulfilled ? DateTime.now() : null,
          );
          try {
            if (task.groupId != null) {
              await ref.read(groupServiceProvider).updateTask(task.toGroupTask());
            } else {
              await ref.read(taskServiceProvider).updateTask(updated);
            }
          } catch (e) {
            debugPrint('Error moving task: $e');
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            key: isDone ? _doneColumnKey : null,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isHovered
                  ? color.withValues(alpha: 0.25)
                  : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: isHovered
                  ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
                  : null,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Text(
                      '$title (${tasks.length})',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return LongPressDraggable<Task>(
                        data: task,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 120,
                            child: Opacity(
                              opacity: 0.85,
                              child: TaskListItem(
                                key: ValueKey('drag-${task.id}'),
                                task: task,
                                selectedIndex:
                                    TaskStatus.values.indexOf(task.status),
                                userInitial: widget.userInitial,
                                compact: true,
                                showSubtasks: false,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: TaskListItem(
                            key: ValueKey(task.id),
                            task: task,
                            selectedIndex:
                                TaskStatus.values.indexOf(task.status),
                            userInitial: widget.userInitial,
                            compact: true,
                            showSubtasks: false,
                          ),
                        ),
                        child: TaskListItem(
                          key: ValueKey(task.id),
                          task: task,
                          selectedIndex:
                              TaskStatus.values.indexOf(task.status),
                          userInitial: widget.userInitial,
                          compact: true,
                          onPortalFulfill: _startPortal,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PortalGhost extends StatefulWidget {
  final Task task;
  final Offset startPos;
  final Offset endPos;
  final Size cardSize;
  final VoidCallback onDone;

  const _PortalGhost({
    required this.task,
    required this.startPos,
    required this.endPos,
    required this.cardSize,
    required this.onDone,
  });

  @override
  State<_PortalGhost> createState() => _PortalGhostState();
}

class _PortalGhostState extends State<_PortalGhost>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _positionAnim = Tween<Offset>(
      begin: widget.startPos,
      end: widget.endPos,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnim = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDone();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.task.category.color);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnim.value.dx,
          top: _positionAnim.value.dy,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _opacityAnim.value,
              child: Container(
                width: widget.cardSize.width,
                height: widget.cardSize.height,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
