import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrioritySelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const PrioritySelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priorities',
          style: TextStyle(
            fontSize: 24,
            color: CupertinoColors.lightBackgroundGray,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPriorityOption('High', 0),
            _buildPriorityOption('Medium', 1),
            _buildPriorityOption('Low', 2),
            _buildPriorityOption('None', 3),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityOption(String label, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onChanged(index),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? CupertinoColors.white : CupertinoColors.lightBackgroundGray,
                width: 2,
              ),
            ),
            child: isSelected 
              ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: CupertinoColors.white, shape: BoxShape.circle)) 
              : Container(width: 8, height: 8, color: Colors.transparent),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? CupertinoColors.white : CupertinoColors.lightBackgroundGray,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
