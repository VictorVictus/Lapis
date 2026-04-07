import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';


class RecurrenceConfigurator extends StatelessWidget {
  final bool isRecurrent;
  final ValueChanged<bool> onRecurrenceToggle;
  final RecurrentFrequency selectedFrequency;
  final ValueChanged<RecurrentFrequency> onFrequencyChanged;
  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onWeekdaysChanged;
  final int customInterval;
  final ValueChanged<int> onCustomIntervalChanged;
  final RecurrentFrequency customUnit;
  final ValueChanged<RecurrentFrequency> onCustomUnitChanged;

  const RecurrenceConfigurator({
    super.key,
    required this.isRecurrent,
    required this.onRecurrenceToggle,
    required this.selectedFrequency,
    required this.onFrequencyChanged,
    required this.selectedWeekdays,
    required this.onWeekdaysChanged,
    required this.customInterval,
    required this.onCustomIntervalChanged,
    required this.customUnit,
    required this.onCustomUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRadioOption('One-Time', false),
            const SizedBox(width: 20),
            _buildRadioOption('Recurrent', true),
          ],
        ),
        if (isRecurrent) ...[
          const SizedBox(height: 30),
          const Text(
            'Recurrence',
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.lightBackgroundGray,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: CupertinoColors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: CupertinoPicker(
              itemExtent: 32,
              onSelectedItemChanged: (int index) {
                onFrequencyChanged(RecurrentFrequency.values[index]);
              },
              children: RecurrentFrequency.values.map((e) {
                return Text(
                  e.name.toUpperCase(), 
                  style: const TextStyle(color: Colors.white),
                );
              }).toList(),
            ),
          ),

          // Weekly Options
          if (selectedFrequency == RecurrentFrequency.weekly) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final dayIndex = index + 1; // 1=Mon, 7=Sun
                final isSelected = selectedWeekdays.contains(dayIndex);
                final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return GestureDetector(
                  onTap: () {
                    final newSet = Set<int>.from(selectedWeekdays);
                    if (isSelected) {
                      newSet.remove(dayIndex);
                    } else {
                      newSet.add(dayIndex);
                    }
                    onWeekdaysChanged(newSet);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      dayNames[index],
                      style: TextStyle(
                        color: isSelected ? Colors.blue : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],

          // Custom Options
          if (selectedFrequency == RecurrentFrequency.custom) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Every',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  // Interval Picker
                  SizedBox(
                    width: 50,
                    height: 100,
                    child: CupertinoPicker(
                      itemExtent: 32,
                      onSelectedItemChanged: (int index) {
                         onCustomIntervalChanged(index + 1);
                      },
                      children: List.generate(30, (index) => Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Unit Widget
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CupertinoPicker(
                      itemExtent: 32,
                      onSelectedItemChanged: (int index) {
                        // Map 0->Daily, 1->Weekly, 2->Monthly
                        if (index == 0) onCustomUnitChanged(RecurrentFrequency.daily);
                        if (index == 1) onCustomUnitChanged(RecurrentFrequency.weekly);
                        if (index == 2) onCustomUnitChanged(RecurrentFrequency.monthly);
                      },
                      children: const [
                        Center(child: Text('Days', style: TextStyle(color: Colors.white))),
                        Center(child: Text('Weeks', style: TextStyle(color: Colors.white))),
                        Center(child: Text('Months', style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRadioOption(String label, bool value) {
     final isSelected = isRecurrent == value;
     return GestureDetector(
       onTap: () => onRecurrenceToggle(value),
       child: Row(
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
              : Container(width: 8, height: 8, color: CupertinoColors.transparent),
          ),
           const SizedBox(width: 8),
           Text(label, style: TextStyle(
             color: isSelected ? CupertinoColors.white : CupertinoColors.lightBackgroundGray,
           )),
         ],
       ),
     );
  }
}
