import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/services/category_service.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

const _colorOptions = [
  Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
  Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
  Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
  Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
  Colors.brown, Colors.grey, Colors.blueGrey,
];

class CategoryDialogs {
  static Future<void> showCreateCategoryDialog(BuildContext context, WidgetRef ref) async {
    String categoryName = '';
    Color selectedColor = Colors.blue;
    final TextEditingController nameController = TextEditingController();

    await showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('New Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: 'Name',
                    style: const TextStyle(color: CupertinoColors.white),
                    placeholderStyle: const TextStyle(color: CupertinoColors.lightBackgroundGray),
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.lightBackgroundGray),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorOptions.map((c) => GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selectedColor == c ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: CupertinoColors.destructiveRed)),
                ),
                CupertinoDialogAction(
                  onPressed: () async {
                    categoryName = nameController.text.trim();
                    if (categoryName.isNotEmpty) {
                      final randomId = FirebaseFirestore.instance.collection('temp').doc().id;
                      final newCategory = TaskCategory(
                        id: randomId,
                        name: categoryName,
                        color: selectedColor.toARGB32(),
                      );
                      
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        try {
                          await ref.read(categoryServiceProvider).createCategory(newCategory, user.uid);
                          ref.read(addTaskProvider.notifier).updateCategory(newCategory);
                        } catch (e) {
                          debugPrint('Error creating category: $e');
                        }
                      }
                      
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Accept', style: TextStyle(color: CupertinoColors.systemGreen)),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }
}
