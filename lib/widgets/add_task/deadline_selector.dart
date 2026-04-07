import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

class DeadlineSelector extends ConsumerWidget {
  const DeadlineSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDeadline = ref.watch(addTaskProvider.select((s) => s.hasDeadline));
    final deadline = ref.watch(addTaskProvider.select((s) => s.deadline));

    return Column(
      children: [
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
              value: hasDeadline,
              onChanged: (value) {
                ref.read(addTaskProvider.notifier).updateHasDeadline(value);
              },
            ),
          ],
        ),
        if (hasDeadline) ...[
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: CupertinoColors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: deadline ?? DateTime.now().add(const Duration(days: 1)),
                minimumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newDate) {
                  ref.read(addTaskProvider.notifier).updateDeadline(newDate);
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
