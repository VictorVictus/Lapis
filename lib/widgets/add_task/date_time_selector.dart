import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

class DateTimeSelector extends ConsumerWidget {
  const DateTimeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledAt = ref.watch(addTaskProvider.select((s) => s.scheduledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date and Time',
          style: TextStyle(
            fontSize: 18,
            color: CupertinoColors.lightBackgroundGray,
          ),
        ),
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
              initialDateTime: scheduledAt,
              onDateTimeChanged: (DateTime newDate) {
                ref.read(addTaskProvider.notifier).updateScheduledAt(newDate);
              },
            ),
          ),
        ),
      ],
    );
  }
}
