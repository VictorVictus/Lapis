import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

class TaskNotesInput extends ConsumerWidget {
  const TaskNotesInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(addTaskProvider.select((s) => s.notes));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(
            fontSize: 18,
            color: CupertinoColors.lightBackgroundGray,
          ),
        ),
        TextField(
          onChanged: (value) => ref.read(addTaskProvider.notifier).updateNotes(value),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            hintText: 'Add a description of your task',
            hintStyle: TextStyle(color: CupertinoColors.extraLightBackgroundGray),
          ),
          style: const TextStyle(fontSize: 14, color: Colors.white),
          controller: TextEditingController(text: notes)..selection = TextSelection.fromPosition(TextPosition(offset: notes.length)),
        ),
      ],
    );
  }
}
