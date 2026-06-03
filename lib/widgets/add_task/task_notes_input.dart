import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

class TaskNotesInput extends ConsumerStatefulWidget {
  const TaskNotesInput({super.key});

  @override
  ConsumerState<TaskNotesInput> createState() => _TaskNotesInputState();
}

class _TaskNotesInputState extends ConsumerState<TaskNotesInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final notes = ref.read(addTaskProvider.select((s) => s.notes));
    _controller = TextEditingController(text: notes);
    _controller.addListener(() {
      ref.read(addTaskProvider.notifier).updateNotes(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          controller: _controller,
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
        ),
      ],
    );
  }
}
