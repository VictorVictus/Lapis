import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/widgets/task_list_view.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';

/// The "Clear all" button appears in the flat list when:
///   selectedIndex == 2 (Fulfilled tab) && tasks.length >= 2
///
/// This function reimplements the logic from task_list_view.dart
/// so it can be tested without rendering the full widget tree.
bool shouldShowClearAll({required int selectedIndex, required int fulfilledCount}) {
  final isDone = TaskStatus.values[selectedIndex] == TaskStatus.fulfilled;
  return isDone && fulfilledCount >= 2;
}

final _doneTask = (int i) => Task(
  id: 't$i',
  userId: 'u1',
  title: 'Task $i',
  category: TaskCategory(id: 'c1', name: 'General', color: 0xFF9E9E9E),
  createdAt: DateTime(2026, 1, 1),
  status: TaskStatus.fulfilled,
  completedAt: DateTime(2026, 6, 10),
);

void main() {
  group('Clear all completed button logic', () {
    test('shows when on Fulfilled tab with 2+ tasks', () {
      expect(shouldShowClearAll(selectedIndex: 2, fulfilledCount: 2), isTrue);
      expect(shouldShowClearAll(selectedIndex: 2, fulfilledCount: 10), isTrue);
    });

    test('hides when on Fulfilled tab with < 2 tasks', () {
      expect(shouldShowClearAll(selectedIndex: 2, fulfilledCount: 0), isFalse);
      expect(shouldShowClearAll(selectedIndex: 2, fulfilledCount: 1), isFalse);
    });

    test('hides when not on Fulfilled tab regardless of count', () {
      expect(shouldShowClearAll(selectedIndex: 0, fulfilledCount: 5), isFalse);
      expect(shouldShowClearAll(selectedIndex: 1, fulfilledCount: 5), isFalse);
    });
  });
}
