import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/services/category_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final userCategoriesStreamProvider = StreamProvider.autoDispose<List<TaskCategory>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  
  return ref.watch(categoryServiceProvider).getCategoriesForUser(user.uid);
});

final allCategoriesProvider = Provider.autoDispose<List<TaskCategory>>((ref) {
  final defaultCategories = ref.watch(categoryServiceProvider).getDefaultCategories();
  final userCategories = ref.watch(userCategoriesStreamProvider).value ?? [];
  
  return [...defaultCategories, ...userCategories];
});
