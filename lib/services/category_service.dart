import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/services/sync_coordinator.dart';

final categoryServiceProvider = Provider((ref) => CategoryService(ref));

class CategoryService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CategoryService(this._ref);

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

  Future<void> createCategory(TaskCategory category, String userId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      final categoryData = category.toMap();
      categoryData['userId'] = userId;

      await _firestore
          .collection('categories')
          .doc(category.id)
          .set(categoryData);
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore.collection('categories').doc(categoryId).delete();
    });
  }

  List<TaskCategory> getDefaultCategories() {
    return [
      TaskCategory(id: 'default_work', name: 'Work', color: 0xFF1E88E5),
      TaskCategory(id: 'default_health', name: 'Health', color: 0xFF43A047),
      TaskCategory(id: 'default_hobbies', name: 'Hobbies', color: 0xFFFB8C00),
      TaskCategory(id: 'default_chores', name: 'Chores', color: 0xFF8E24AA),
    ];
  }
}
