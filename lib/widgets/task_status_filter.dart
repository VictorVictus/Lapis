import 'dart:ui';
import 'package:flutter/material.dart';

class TaskStatusFilter extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int undoneCount;
  final int inProgressCount;
  final int fulfilledCount;

  const TaskStatusFilter({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.undoneCount = 0,
    this.inProgressCount = 0,
    this.fulfilledCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      alignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTab(context, 'Undone', 0, undoneCount),
        _buildTab(context, 'In Progress', 1, inProgressCount),
        _buildTab(context, 'Fulfilled', 2, fulfilledCount),
      ],
    );
  }

  Widget _buildTab(BuildContext context, String title, int index, int count) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isSelected ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isSelected ? 0.35 : 0.15),
                  ),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isSelected ? 0.9 : 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -5,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Center(
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
