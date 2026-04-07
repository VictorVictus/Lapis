import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/models/task.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/services/task_service.dart';
import 'package:flutter/foundation.dart';

class AddTaskState {
  final String title;
  final String notes;
  final int priorityIndex;
  final TaskCategory? selectedCategory;
  final DateTime scheduledAt;
  final bool isRecurrent;
  final RecurrentFrequency recurrentFrequency;
  final Set<int> selectedWeekdays;
  final int customInterval;
  final RecurrentFrequency customUnit;
  final bool hasDeadline;
  final DateTime? deadline;
  final bool isSaving;

  AddTaskState({
    this.title = '',
    this.notes = '',
    this.priorityIndex = 0,
    this.selectedCategory,
    required this.scheduledAt,
    this.isRecurrent = false,
    this.recurrentFrequency = RecurrentFrequency.daily,
    this.selectedWeekdays = const {},
    this.customInterval = 1,
    this.customUnit = RecurrentFrequency.daily,
    this.hasDeadline = false,
    this.deadline,
    this.isSaving = false,
  });

  AddTaskState copyWith({
    String? title,
    String? notes,
    int? priorityIndex,
    TaskCategory? selectedCategory,
    DateTime? scheduledAt,
    bool? isRecurrent,
    RecurrentFrequency? recurrentFrequency,
    Set<int>? selectedWeekdays,
    int? customInterval,
    RecurrentFrequency? customUnit,
    bool? hasDeadline,
    DateTime? deadline,
    bool? isSaving,
  }) {
    return AddTaskState(
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priorityIndex: priorityIndex ?? this.priorityIndex,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isRecurrent: isRecurrent ?? this.isRecurrent,
      recurrentFrequency: recurrentFrequency ?? this.recurrentFrequency,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      customInterval: customInterval ?? this.customInterval,
      customUnit: customUnit ?? this.customUnit,
      hasDeadline: hasDeadline ?? this.hasDeadline,
      deadline: deadline ?? this.deadline,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class AddTaskNotifier extends Notifier<AddTaskState> {
  @override
  AddTaskState build() {
    return AddTaskState(scheduledAt: DateTime.now());
  }

  void updateTitle(String title) => state = state.copyWith(title: title);
  void updateNotes(String notes) => state = state.copyWith(notes: notes);
  void updatePriority(int index) => state = state.copyWith(priorityIndex: index);
  void updateCategory(TaskCategory? category) => state = state.copyWith(selectedCategory: category);
  void updateScheduledAt(DateTime date) => state = state.copyWith(scheduledAt: date);
  void updateIsRecurrent(bool value) => state = state.copyWith(isRecurrent: value);
  void updateFrequency(RecurrentFrequency freq) => state = state.copyWith(recurrentFrequency: freq);
  void updateWeekdays(Set<int> days) => state = state.copyWith(selectedWeekdays: days);
  void updateCustomInterval(int interval) => state = state.copyWith(customInterval: interval);
  void updateCustomUnit(RecurrentFrequency unit) => state = state.copyWith(customUnit: unit);
  void updateHasDeadline(bool value) {
    DateTime? newDeadline = state.deadline;
    if (value && newDeadline == null) {
      newDeadline = DateTime.now().add(const Duration(days: 1));
    }
    state = state.copyWith(hasDeadline: value, deadline: newDeadline);
  }
  void updateDeadline(DateTime date) => state = state.copyWith(deadline: date);

  Future<bool> saveTask() async {
    if (state.title.trim().isEmpty) return false;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    state = state.copyWith(isSaving: true);

    try {
      final taskId = FirebaseFirestore.instance.collection('tasks').doc().id;
      
      RecurrentConfig? recurrentConfig;
      if (state.isRecurrent) {
        int interval = 1;
        RecurrentFrequency freq = state.recurrentFrequency;
        
        if (state.recurrentFrequency == RecurrentFrequency.custom) {
          interval = state.customInterval;
          freq = state.customUnit;
        }
        
        recurrentConfig = RecurrentConfig(
          frequency: freq,
          interval: interval,
          weekdays: state.recurrentFrequency == RecurrentFrequency.weekly 
            ? state.selectedWeekdays.toList() 
            : null,
        );
      }

      final newTask = Task(
        id: taskId,
        userId: user.uid,
        title: state.title.trim(),
        category: state.selectedCategory!, // Assuming category is always selected
        createdAt: DateTime.now(),
        status: TaskStatus.undone,
        type: state.isRecurrent ? TaskType.recurrent : TaskType.oneTime,
        priority: TaskPriority.values[state.priorityIndex],
        scheduledAt: state.scheduledAt,
        deadline: state.hasDeadline ? state.deadline : null,
        recurrentConfig: recurrentConfig,
        notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
      );

      await ref.read(taskServiceProvider).createTask(newTask);
      return true;
    } catch (e) {
      debugPrint('Error saving task in provider: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final addTaskProvider = NotifierProvider.autoDispose<AddTaskNotifier, AddTaskState>(AddTaskNotifier.new);
