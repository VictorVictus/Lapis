import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/services/category_service.dart';
import 'package:to_do_app/providers/add_task_provider.dart';

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
                  GestureDetector(
                    onTap: () async {
                      final Color? pickedColor = await showColorPickerDialog(context, selectedColor);
                      if (pickedColor != null) {
                        setDialogState(() {
                          selectedColor = pickedColor;
                        });
                      }
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Select Color',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
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
                        color: selectedColor.value,
                      );
                      
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        try {
                          await ref.read(categoryServiceProvider).createCategory(newCategory, user.uid);
                          // Also update selection in provider
                          ref.read(addTaskProvider.notifier).updateCategory(newCategory);
                        } catch (e) {
                          debugPrint('Error creating category: $e');
                        }
                      }
                      
                      Navigator.pop(context);
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

  static Future<Color?> showColorPickerDialog(BuildContext context, Color currentColor) async {
    Color pickerColor = currentColor;

    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Colors'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              displayThumbColor: true,
              enableAlpha: false,
              labelTypes: const [ColorLabelType.hex],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel', style: TextStyle(color: CupertinoColors.destructiveRed)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, pickerColor),
              child: Text('Select', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }
}
