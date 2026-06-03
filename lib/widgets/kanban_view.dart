import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:to_do_app/services/task_service.dart';
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

class _KanbanViewState extends ConsumerState<KanbanView> {
  int? _dragTargetIndex;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider(widget.userId));

    return tasksAsync.when(
      data: (allTasks) {
        final active = allTasks.where((t) => t.status == TaskStatus.undone && !t.isArchived).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        final inProgress = allTasks.where((t) => t.status == TaskStatus.inProgress && !t.isArchived).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        final done = allTasks.where((t) => t.status == TaskStatus.fulfilled && !t.isArchived).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        final columns = [
          ('Undone', active, TaskStatus.undone),
          ('In Progress', inProgress, TaskStatus.inProgress),
          ('Done', done, TaskStatus.fulfilled),
        ];
        final scheme = Theme.of(context).colorScheme;
        final saturated = _saturate;
        final colors = [saturated(scheme.tertiary), saturated(scheme.secondary), saturated(scheme.primary)];

        return Row(
          children: List.generate(columns.length, (i) {
            final (title, tasks, status) = columns[i];
            return _buildColumn(context, title, tasks, colors[i], status, i, ref);
          }),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildColumn(BuildContext context, String title, List<Task> tasks, Color color, TaskStatus targetStatus, int index, WidgetRef ref) {
    final isHovered = _dragTargetIndex == index;
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
            completedAt: targetStatus == TaskStatus.fulfilled ? DateTime.now() : null,
          );
          try {
            await ref.read(taskServiceProvider).updateTask(updated);
          } catch (e) {
            debugPrint('Error moving task: $e');
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                                selectedIndex: TaskStatus.values.indexOf(task.status),
                                userInitial: widget.userInitial,
                                compact: true,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: TaskListItem(
                            key: ValueKey(task.id),
                            task: task,
                            selectedIndex: TaskStatus.values.indexOf(task.status),
                            userInitial: widget.userInitial,
                            compact: true,
                          ),
                        ),
                        child: TaskListItem(
                          key: ValueKey(task.id),
                          task: task,
                          selectedIndex: TaskStatus.values.indexOf(task.status),
                          userInitial: widget.userInitial,
                          compact: true,
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
