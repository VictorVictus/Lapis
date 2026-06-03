import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';

bool matchesSmartFilter(Task task, SmartFilter filter) {
  final now = DateTime.now();
  switch (filter) {
    case SmartFilter.all:
      return true;
    case SmartFilter.today:
      return task.scheduledAt != null &&
          task.scheduledAt!.day == now.day &&
          task.scheduledAt!.month == now.month &&
          task.scheduledAt!.year == now.year;
    case SmartFilter.thisWeek:
      if (task.scheduledAt == null) return false;
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return task.scheduledAt!.isAfter(weekStart.subtract(const Duration(hours: 1)));
    case SmartFilter.overdue:
      return task.deadline != null && task.deadline!.isBefore(now);
    case SmartFilter.highPriority:
      return task.priority == TaskPriority.high;
    case SmartFilter.hasDeadline:
      return task.deadline != null;
    case SmartFilter.noDeadline:
      return task.deadline == null;
    case SmartFilter.thisMonth:
      if (task.scheduledAt == null) return false;
      return task.scheduledAt!.month == now.month &&
          task.scheduledAt!.year == now.year;
    case SmartFilter.recurring:
      return task.type == TaskType.recurrent;
  }
}
