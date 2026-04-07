import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

class TaskTitleInput extends ConsumerWidget {
  const TaskTitleInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(addTaskProvider.select((s) => s.title));

    return TextField(
      onChanged: (value) => ref.read(addTaskProvider.notifier).updateTitle(value),
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
      controller: TextEditingController(text: title)..selection = TextSelection.fromPosition(TextPosition(offset: title.length)),
    );
  }
}
