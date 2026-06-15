import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/core/recurrence_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:to_do_app/services/widget_data_service.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/services/sync_coordinator.dart';

final taskServiceProvider = Provider((ref) => TaskService(ref));

class TaskService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Max time a Firestore stream can hang before emitting an error.
  static const Duration _streamTimeout = Duration(seconds: 60);

  TaskService(this._ref);

  Future<void> _scheduleNotificationUnsafe(Task task) async {
    try {
      await NotificationService().scheduleTaskNotification(task);
    } catch (e) {
      debugPrint('Notification scheduling failed (non-fatal): $e');
    }
  }

  Future<void> createTask(Task task) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      final docRef = _firestore.collection('tasks').doc(task.id);
      await docRef.set(task.toMap());

      unawaited(_scheduleNotificationUnsafe(task));
      unawaited(WidgetDataService.updateTodayTasks(task.userId));
      _ref.invalidate(taskCountsProvider(task.userId));
    });
  }

  Future<void> updateTask(Task task) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      final docRef = _firestore.collection('tasks').doc(task.id);
      await docRef.update(task.toMap());

      if (task.status == TaskStatus.fulfilled && task.type == TaskType.recurrent) {
        unawaited(_spawnNextRecurrence(task));
      }

      unawaited(_scheduleNotificationUnsafe(task));
      unawaited(WidgetDataService.updateTodayTasks(task.userId));
      _ref.invalidate(taskCountsProvider(task.userId));
    });
  }

  Future<void> _spawnNextRecurrence(Task task) async {
    try {
      final nextDate = computeNextRecurrence(task);
      final nextTask = Task(
        id: _firestore.collection('tasks').doc().id,
        userId: task.userId,
        title: task.title,
        category: task.category,
        createdAt: DateTime.now(),
        order: task.order,
        status: TaskStatus.undone,
        type: TaskType.recurrent,
        priority: task.priority,
        scheduledAt: nextDate,
        deadline: task.deadline,
        recurrentConfig: task.recurrentConfig,
        notes: task.notes,
        pinned: task.pinned,
      );
      await createTask(nextTask);
    } catch (e) {
      debugPrint('Error spawning next recurrence: $e');
    }
  }

  Future<void> deleteTask(String taskId, String userId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      final docRef = _firestore.collection('tasks').doc(taskId);
      await docRef.delete();

      unawaited(NotificationService().cancelNotification(taskId));
      unawaited(WidgetDataService.updateTodayTasks(userId));
      _ref.invalidate(taskCountsProvider(userId));
    });
  }

  Stream<List<Task>> _withTimeout(Stream<List<Task>> stream) {
    return stream.timeout(
      _streamTimeout,
      onTimeout: (sink) => sink.addError(
        TimeoutException('Firestore stream timed out after 60s'),
      ),
    );
  }

  Stream<List<Task>> getTasksForUser(String userId) {
    return _withTimeout(
      _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Task.fromMap(doc.data(), doc.id))
                .where((task) => !task.isArchived)
                .toList(),
          ),
    );
  }

  Future<Map<TaskStatus, int>> getTaskCounts(String userId) async {
    final results = await Future.wait([
      _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: TaskStatus.undone.index)
          .count()
          .get(),
      _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: TaskStatus.inProgress.index)
          .count()
          .get(),
      _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: TaskStatus.fulfilled.index)
          .count()
          .get(),
    ]);

    return {
      TaskStatus.undone: results[0].count ?? 0,
      TaskStatus.inProgress: results[1].count ?? 0,
      TaskStatus.fulfilled: results[2].count ?? 0,
    };
  }
}

