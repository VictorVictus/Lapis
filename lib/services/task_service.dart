import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/sync_provider.dart';

import 'package:to_do_app/services/notification_service.dart';

final taskServiceProvider = Provider((ref) => TaskService(ref));

class TaskService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TaskService(this._ref);

  Future<void> _runWithSyncStatus(Future<void> Function() action) async {
    _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
    try {
      // Pre-flight check: If there's no network at all, fail immediately
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Offline: Connect to use the internet for syncing.');
      }

      // 10s timeout: Don't wait for Firestore indefinitely
      await action().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timeout: Server is too slow.'),
      );
      
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.idle);
      _ref.read(showSuccessIndicatorProvider.notifier).setVisible(true);
      
      // Reset success indicator after a delay
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(showSuccessIndicatorProvider.notifier).setVisible(false);
      });
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
      _ref.read(lastSyncErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
  }

  Future<void> createTask(Task task) async {
    await _runWithSyncStatus(() async {
      final docRef = _firestore.collection('tasks').doc(task.id);
      await docRef.set(task.toMap());
      
      // Schedule local notification
      await NotificationService().scheduleTaskNotification(task);
    });
  }

  Future<void> updateTask(Task task) async {
    await _runWithSyncStatus(() async {
      final docRef = _firestore.collection('tasks').doc(task.id);
      await docRef.update(task.toMap());
      
      // Update/Reschedule notification
      await NotificationService().scheduleTaskNotification(task);
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _runWithSyncStatus(() async {
      final docRef = _firestore.collection('tasks').doc(taskId);
      await docRef.delete();
      
      // Cancel pending notification
      await NotificationService().cancelNotification(taskId);
    });
  }

  Stream<List<Task>> getTasksForUser(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}



