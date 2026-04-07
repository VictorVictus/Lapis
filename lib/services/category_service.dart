import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/sync_provider.dart';

final categoryServiceProvider = Provider((ref) => CategoryService(ref));

class CategoryService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CategoryService(this._ref);

  Future<void> _runWithSyncStatus(Future<void> Function() action) async {
    _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Offline: Connect to use the internet.');
      }

      await action().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Network Timeout: Are you connected?'),
      );
      
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.idle);
      _ref.read(showSuccessIndicatorProvider.notifier).setVisible(true);
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(showSuccessIndicatorProvider.notifier).setVisible(false);
      });
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
      _ref.read(lastSyncErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
  }

  // Get all categories for a specific user
  Stream<List<TaskCategory>> getCategoriesForUser(String userId) {
    return _firestore
        .collection('categories')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskCategory.fromMap(doc.data()))
              .toList(),
        );
  }

  // Create a new category for a user
  Future<void> createCategory(TaskCategory category, String userId) async {
    await _runWithSyncStatus(() async {
      final categoryData = category.toMap();
      categoryData['userId'] = userId;
      
      await _firestore
          .collection('categories')
          .doc(category.id)
          .set(categoryData);
    });
  }

  // Delete a category
  Future<void> deleteCategory(String categoryId) async {
    await _runWithSyncStatus(() async {
      await _firestore.collection('categories').doc(categoryId).delete();
    });
  }

  // Get default categories (always available for all users)
  List<TaskCategory> getDefaultCategories() {
    return [
      TaskCategory(id: 'default_work', name: 'Work', color: 0xFF1E88E5),
      TaskCategory(id: 'default_health', name: 'Health', color: 0xFF43A047),
      TaskCategory(id: 'default_hobbies', name: 'Hobbies', color: 0xFFFB8C00),
      TaskCategory(id: 'default_chores', name: 'Chores', color: 0xFF8E24AA),
    ];
  }
}
