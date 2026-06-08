import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:to_do_app/theme/app_theme.dart';

Future<SubTask?> showSubtaskCreateSheet({
  required BuildContext context,
  required String taskId,
  required String userId,
}) {
  return showModalBottomSheet<SubTask>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SubtaskCreateSheet(taskId: taskId, userId: userId),
  );
}

class _SubtaskCreateSheet extends StatefulWidget {
  final String taskId;
  final String userId;

  const _SubtaskCreateSheet({required this.taskId, required this.userId});

  @override
  State<_SubtaskCreateSheet> createState() => _SubtaskCreateSheetState();
}

class _SubtaskCreateSheetState extends State<_SubtaskCreateSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _titleFocus = FocusNode();
  TaskPriority _priority = TaskPriority.none;
  DateTime? _deadline;
  bool _showDatePicker = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.requestFocus();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    Navigator.pop(
      context,
      SubTask(
        id: id,
        taskId: widget.taskId,
        userId: widget.userId,
        title: title,
        priority: _priority,
        deadline: _deadline,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        order: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.gradientColors(context).primary,
              AppTheme.gradientColors(context).secondary,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    hintText: 'Subtask title',
                    hintStyle: TextStyle(color: CupertinoColors.lightBackgroundGray),
                  ),
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 30),
                Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 20),
                const Text(
                  'Priority',
                  style: TextStyle(
                    fontSize: 24,
                    color: CupertinoColors.lightBackgroundGray,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _priorityOption('High', TaskPriority.high, Colors.red),
                    _priorityOption('Medium', TaskPriority.medium, Colors.orange),
                    _priorityOption('Low', TaskPriority.low, Colors.amber),
                    _priorityOption('None', TaskPriority.none, CupertinoColors.lightBackgroundGray),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 20),
                const Text(
                  'Configuration',
                  style: TextStyle(
                    fontSize: 24,
                    color: CupertinoColors.lightBackgroundGray,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    hintText: 'Add notes...',
                    hintStyle: TextStyle(color: CupertinoColors.lightBackgroundGray),
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  maxLines: 2,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Deadline',
                      style: TextStyle(
                        fontSize: 18,
                        color: CupertinoColors.lightBackgroundGray,
                      ),
                    ),
                    CupertinoSwitch(
                      value: _showDatePicker,
                      onChanged: (val) => setState(() => _showDatePicker = val),
                    ),
                  ],
                ),
                if (_showDatePicker) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(brightness: Brightness.dark),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _deadline ?? DateTime.now().add(const Duration(days: 1)),
                        minimumDate: DateTime.now(),
                        onDateTimeChanged: (dt) => setState(() => _deadline = dt),
                      ),
                    ),
                  ),
                  if (_deadline != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => setState(() { _deadline = null; }),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.clear_circled_solid, size: 14, color: CupertinoColors.destructiveRed),
                            SizedBox(width: 4),
                            Text(
                              'Clear date',
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.destructiveRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: CupertinoColors.destructiveRed)),
                    ),
                    CupertinoButton.filled(
                      onPressed: _titleController.text.trim().isEmpty ? null : _submit,
                      child: const Text('Add Subtask'),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      );
    }

  Widget _priorityOption(String label, TaskPriority p, Color dotColor) {
    final isSelected = _priority == p;
    return GestureDetector(
      onTap: () => setState(() => _priority = p),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? CupertinoColors.white : CupertinoColors.lightBackgroundGray,
                width: 2,
              ),
            ),
            child: isSelected
              ? Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle))
              : Container(width: 8, height: 8, color: Colors.transparent),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? CupertinoColors.white : CupertinoColors.lightBackgroundGray,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
