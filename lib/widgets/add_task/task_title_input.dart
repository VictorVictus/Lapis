import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

class TaskTitleInput extends ConsumerStatefulWidget {
  const TaskTitleInput({super.key});

  @override
  ConsumerState<TaskTitleInput> createState() => _TaskTitleInputState();
}

class _TaskTitleInputState extends ConsumerState<TaskTitleInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final title = ref.read(addTaskProvider.select((s) => s.title));
    _controller = TextEditingController(text: title);
    _controller.addListener(() {
      ref.read(addTaskProvider.notifier).updateTitle(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
        ),
        hintText: 'What do you need to do?',
        hintStyle: TextStyle(color: CupertinoColors.lightBackgroundGray),
      ),
      style: const TextStyle(fontSize: 24, color: Colors.white),
    );
  }
}
