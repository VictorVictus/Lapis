import 'package:flutter/material.dart';

class TaskStatusFilter extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int undoneCount;
  final int inProgressCount;
  final int fulfilledCount;

  const TaskStatusFilter({
    Key? key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.undoneCount = 0,
    this.inProgressCount = 0,
    this.fulfilledCount = 0,
  }) : super(key: key);

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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => onTabSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: index == 0 ? Curves.bounceInOut : Curves.easeInOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selectedIndex == index
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: selectedIndex == index
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.primary)
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]),
                fontWeight: FontWeight.bold,
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
              decoration: const BoxDecoration(
                color: Color(0xFFC0392B), // Deep notification red
                shape: BoxShape.circle,
                boxShadow: [
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
    );
  }
}
