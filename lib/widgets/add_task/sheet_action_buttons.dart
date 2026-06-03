import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

class SheetActionButtons extends ConsumerWidget {
  const SheetActionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = ref.watch(addTaskProvider.select((s) => s.isSaving));
    final isEditing = ref.watch(addTaskProvider.select((s) => s.isEditing));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CupertinoButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: CupertinoColors.destructiveRed)),
        ),
        CupertinoButton.filled(
          onPressed: isSaving
              ? null
              : () async {
                  final success = await ref.read(addTaskProvider.notifier).saveTask();
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.redAccent,
                        content: Text('Failed to save task. Please try again.'),
                      ),
                    );
                  }
                },
          child: isSaving
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text(isEditing ? 'Save' : 'Add Task', style: const TextStyle(color: CupertinoColors.systemCyan)),
        ),
      ],
    );
  }
}
