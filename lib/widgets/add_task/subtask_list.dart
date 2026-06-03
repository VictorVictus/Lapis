import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:to_do_app/providers/subtask_provider.dart';
import 'package:to_do_app/services/subtask_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubtaskList extends ConsumerStatefulWidget {
  final String taskId;

  const SubtaskList({super.key, required this.taskId});

  @override
  ConsumerState<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends ConsumerState<SubtaskList> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addSubTask() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final service = ref.read(subTaskServiceProvider);
    final id = service.generateId();
    final subTask = SubTask(
      id: id,
      taskId: widget.taskId,
      userId: user.uid,
      title: title,
      order: DateTime.now().millisecondsSinceEpoch,
    );

    await service.createSubTask(subTask);
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _toggleSubTask(SubTask subTask) async {
    await ref.read(subTaskServiceProvider).updateSubTask(
      subTask.copyWith(isDone: !subTask.isDone),
    );
  }

  Future<void> _deleteSubTask(SubTask subTask) async {
    await ref.read(subTaskServiceProvider).deleteSubTask(subTask.id);
  }

  @override
  Widget build(BuildContext context) {
    final subTasksAsync = ref.watch(subTasksProvider(widget.taskId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subtasks',
          style: TextStyle(
            fontSize: 18,
            color: CupertinoColors.lightBackgroundGray,
          ),
        ),
        const SizedBox(height: 12),
        subTasksAsync.when(
          data: (subTasks) => Column(
            children: [
              ...subTasks.map((subTask) => Row(
                key: ValueKey(subTask.id),
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _toggleSubTask(subTask),
                    child: Icon(
                      subTask.isDone
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.circle,
                      color: subTask.isDone
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.lightBackgroundGray,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subTask.title,
                      style: TextStyle(
                        color: CupertinoColors.white,
                        decoration: subTask.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: CupertinoColors.lightBackgroundGray,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _deleteSubTask(subTask),
                    child: const Icon(
                      CupertinoIcons.delete_simple,
                      color: CupertinoColors.destructiveRed,
                      size: 20,
                    ),
                  ),
                ],
              )),
            ],
          ),
          loading: () => const CupertinoActivityIndicator(),
          error: (e, _) => Text(
            'Error loading subtasks',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: 'Add subtask...',
                placeholderStyle: const TextStyle(
                  color: CupertinoColors.lightBackgroundGray,
                ),
                style: const TextStyle(color: CupertinoColors.white),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.lightBackgroundGray),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(10),
                onSubmitted: (_) => _addSubTask(),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              onPressed: _addSubTask,
              child: const Icon(
                CupertinoIcons.add_circled_solid,
                color: CupertinoColors.activeGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
