import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/label.dart';
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
import 'package:to_do_app/theme/app_theme.dart';
import 'package:to_do_app/providers/categories_provider.dart';
import 'package:to_do_app/providers/group_members_cache_provider.dart';
import 'package:to_do_app/providers/label_providers.dart';
import 'package:to_do_app/services/label_service.dart';
import 'package:to_do_app/providers/sections_provider.dart';
import 'package:to_do_app/services/section_service.dart';
import 'package:to_do_app/models/subclasses/section.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  final Task? existingTask;
  final String? groupId;

  const AddTaskSheet({super.key, this.existingTask, this.groupId});

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.existingTask != null) {
          ref.read(addTaskProvider.notifier).initForEdit(widget.existingTask!);
        } else if (widget.groupId != null) {
          ref.read(addTaskProvider.notifier).setGroupId(widget.groupId!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider);
    final addTaskState = ref.watch(addTaskProvider);
    final addTaskNotifier = ref.read(addTaskProvider.notifier);

    ref.listen(allCategoriesProvider, (previous, next) {
      if (next.isEmpty) return;
      if (ref.read(addTaskProvider).selectedCategory == null) {
        Future.microtask(() {
          if (mounted) {
            addTaskNotifier.updateCategory(next.first);
          }
        });
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              const TaskTitleInput(),
              const SizedBox(height: 20),
              CategorySelector(
                categories: categories,
                selectedCategory: addTaskState.selectedCategory,
                onCategorySelected: (cat) => addTaskNotifier.updateCategory(cat),
                onAddCategory: () => CategoryDialogs.showCreateCategoryDialog(context, ref),
              ),
              if (addTaskState.groupId != null) ...[
                const SizedBox(height: 20),
                _MemberPicker(
                  groupId: addTaskState.groupId!,
                  selectedUid: addTaskState.assignedTo,
                  onSelected: (uid) => addTaskNotifier.updateAssignedTo(uid),
                ),
              ],
              const SizedBox(height: 20),
              _SectionPicker(),
              const SizedBox(height: 20),
              _LabelPicker(),
              const SizedBox(height: 30),
              Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
              const SizedBox(height: 20),
              PrioritySelector(
                selectedIndex: addTaskState.priorityIndex,
                onChanged: (index) => addTaskNotifier.updatePriority(index),
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

class _MemberPicker extends ConsumerWidget {
  final String groupId;
  final String? selectedUid;
  final ValueChanged<String?> onSelected;

  const _MemberPicker({
    required this.groupId,
    required this.selectedUid,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cacheAsync = ref.watch(groupMembersCacheProvider(userId));
    return cacheAsync.when(
      data: (cache) {
        final members = cache[groupId] ?? [];
        if (members.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign to',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.lightBackgroundGray.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MemberChip(
                    label: 'Nobody',
                    isSelected: selectedUid == null,
                    onTap: () => onSelected(null),
                  ),
                  const SizedBox(width: 8),
                  ...members.map((m) => _MemberChip(
                    label: m.username,
                    isSelected: selectedUid == m.uid,
                    onTap: () => onSelected(m.uid),
                  )),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LabelPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final labelsAsync = ref.watch(userLabelsProvider(userId));
    final selectedIds = ref.watch(addTaskProvider.select((s) => s.selectedLabelIds));
    final notifier = ref.read(addTaskProvider.notifier);

    return labelsAsync.when(
      data: (labels) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Labels',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.lightBackgroundGray.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (labels.isNotEmpty)
                  ...labels.map((label) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _LabelChip(
                      label: label,
                      isSelected: selectedIds.contains(label.id),
                      onTap: () => notifier.toggleLabel(label.id),
                    ),
                  )),
                _AddLabelButton(),
              ],
            ),
          ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final Label label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LabelChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(label.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label.name,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddLabelButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showCreateLabelDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: CupertinoColors.systemGrey),
            const SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateLabelDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Label name',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
                  Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
                  Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
                  Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
                  Colors.brown, Colors.grey, Colors.blueGrey,
                ].map((color) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selectedColor == color
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final service = ref.read(labelServiceProvider);
                final label = Label(
                  id: service.generateId(userId),
                  name: name,
                  color: selectedColor.toARGB32(),
                  userId: userId,
                );
                await service.createLabel(label);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sectionsAsync = ref.watch(userSectionsProvider(userId));
    final selectedId = ref.watch(addTaskProvider.select((s) => s.selectedSection));
    final notifier = ref.read(addTaskProvider.notifier);

    return sectionsAsync.when(
      data: (sections) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Section',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.lightBackgroundGray.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SectionChip(
                    label: 'None',
                    isSelected: selectedId == null,
                    onTap: () => notifier.updateSection(null),
                  ),
                  const SizedBox(width: 8),
                  ...sections.map((s) => _SectionChip(
                    label: s.name,
                    isSelected: selectedId == s.id,
                    onTap: () => notifier.updateSection(s.id),
                  )),
                  _AddSectionButton(),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.systemGrey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 12, color: color),
              ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSectionButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showCreateSectionDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: CupertinoColors.systemGrey),
            const SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSectionDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Section'),
        content: CupertinoTextField(
          controller: nameController,
          placeholder: 'Section name',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final service = ref.read(sectionServiceProvider);
              final sections = ref.read(userSectionsProvider(userId)).asData?.value ?? [];
              final section = Section(
                id: service.generateId(userId),
                name: name,
                order: sections.length,
                userId: userId,
              );
              await service.createSection(section);
              ref.invalidate(userSectionsProvider(userId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemberChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.systemGrey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label.isNotEmpty ? label[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
