import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/widgets/add_task/category_selector.dart';
import 'package:to_do_app/widgets/add_task/priority_selector.dart';
import 'package:to_do_app/widgets/add_task/recurrence_configurator.dart';
import 'package:to_do_app/widgets/add_task/task_title_input.dart';
import 'package:to_do_app/widgets/add_task/task_notes_input.dart';
import 'package:to_do_app/widgets/add_task/date_time_selector.dart';
import 'package:to_do_app/widgets/add_task/deadline_selector.dart';
import 'package:to_do_app/widgets/add_task/sheet_action_buttons.dart';
import 'package:to_do_app/widgets/add_task/category_dialog.dart';
import 'package:to_do_app/providers/add_task_provider.dart';
import 'package:to_do_app/providers/categories_provider.dart';

class AddTaskSheet extends ConsumerWidget {
  const AddTaskSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider);
    final addTaskState = ref.watch(addTaskProvider);
    final addTaskNotifier = ref.read(addTaskProvider.notifier);

    // Initial category selection if none selected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (addTaskState.selectedCategory == null && categories.isNotEmpty) {
        addTaskNotifier.updateCategory(categories[0]);
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
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
              // Handle Bar
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

              const TaskTitleInput(),

              const SizedBox(height: 20),

              CategorySelector(
                categories: categories,
                selectedCategory: addTaskState.selectedCategory,
                onCategorySelected: (cat) => addTaskNotifier.updateCategory(cat),
                onAddCategory: () => CategoryDialogs.showCreateCategoryDialog(context, ref),
              ),

              const SizedBox(height: 30),
              const Divider(color: Colors.black12),
              const SizedBox(height: 20),

              PrioritySelector(
                selectedIndex: addTaskState.priorityIndex,
                onChanged: (index) => addTaskNotifier.updatePriority(index),
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.black12),
              const SizedBox(height: 20),

              const Text(
                'Configuration',
                style: TextStyle(
                  fontSize: 24,
                  color: CupertinoColors.lightBackgroundGray,
                ),
              ),
              const SizedBox(height: 12),

              const TaskNotesInput(),
              const SizedBox(height: 30),

              RecurrenceConfigurator(
                isRecurrent: addTaskState.isRecurrent,
                onRecurrenceToggle: (val) => addTaskNotifier.updateIsRecurrent(val),
                selectedFrequency: addTaskState.recurrentFrequency,
                onFrequencyChanged: (freq) => addTaskNotifier.updateFrequency(freq),
                selectedWeekdays: addTaskState.selectedWeekdays,
                onWeekdaysChanged: (days) => addTaskNotifier.updateWeekdays(days),
                customInterval: addTaskState.customInterval,
                onCustomIntervalChanged: (val) => addTaskNotifier.updateCustomInterval(val),
                customUnit: addTaskState.customUnit,
                onCustomUnitChanged: (val) => addTaskNotifier.updateCustomUnit(val),
              ),

              const SizedBox(height: 30),
              const DateTimeSelector(),
              const SizedBox(height: 30),
              const DeadlineSelector(),
              const SizedBox(height: 40),
              const SheetActionButtons(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
