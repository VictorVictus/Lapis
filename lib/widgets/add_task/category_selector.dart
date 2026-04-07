import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';


class CategorySelector extends StatelessWidget {
  final List<TaskCategory> categories;
  final TaskCategory? selectedCategory;
  final ValueChanged<TaskCategory> onCategorySelected;
  final VoidCallback onAddCategory;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onAddCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...categories.map((category) => _buildCategoryChip(category)),
        _buildAddCategoryButton(),
      ],
    );
  }

  Widget _buildCategoryChip(TaskCategory category) {
    final isSelected = selectedCategory?.id == category.id;
    return GestureDetector(
      onTap: () => onCategorySelected(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
             if(isSelected)
               BoxShadow(
                 color: Colors.black.withOpacity(0.1),
                 blurRadius: 4,
                 offset: const Offset(0, 2),
               )
          ]
        ),
        child: Text(
          category.name,
          style: TextStyle(
            color: isSelected ? Color(category.color) : Colors.blueGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: onAddCategory,
      child: Container(
        padding: const EdgeInsets.all(10), // square-ish
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add, color: Colors.blue),
      ),
    );
  }
}
