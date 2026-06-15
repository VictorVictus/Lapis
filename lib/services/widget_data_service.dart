import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_widget/home_widget.dart';
import 'package:to_do_app/models/task.dart';

class WidgetDataService {
  static const _widgetName = 'LapisTaskWidget';       // iOS name
  static const _androidWidgetName = 'LapisTaskWidgetReceiver'; // Android BroadcastReceiver
  static const _appGroupId = 'group.app.lapis.todo';

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updateTodayTasks(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [0, 1])
        .get();

    final todayTasks = snapshot.docs
        .map((doc) => Task.fromMap(doc.data(), doc.id))
        .where((t) {
      if (t.isArchived) return false;
      final hasDeadlineToday = t.deadline != null &&
          !t.deadline!.isBefore(startOfDay) &&
          t.deadline!.isBefore(endOfDay);
      final hasScheduledToday = t.scheduledAt != null &&
          !t.scheduledAt!.isBefore(startOfDay) &&
          t.scheduledAt!.isBefore(endOfDay);
      final hasNoDate = t.deadline == null && t.scheduledAt == null;
      return hasDeadlineToday || hasScheduledToday || hasNoDate;
    }).toList()
      ..sort((a, b) {
        final pCmp = b.priority.index.compareTo(a.priority.index);
        if (pCmp != 0) return pCmp;
        return a.order.compareTo(b.order);
      });

    await HomeWidget.saveWidgetData('total_pending', todayTasks.length);
    final taskListJson = jsonEncode(todayTasks.map((t) => {
          'id': t.id,
          'title': t.title,
          'status': t.status.index,
          'priority': t.priority.index,
          'category': t.category.name,
          'color': t.category.color.toRadixString(16).padLeft(8, '0'),
        }).toList());
    await HomeWidget.saveWidgetData('tasks_json', taskListJson);

    await HomeWidget.updateWidget(
      name: _widgetName,
      iOSName: _widgetName,
      androidName: _androidWidgetName,
    );
  }

  static Future<void> updateAllWidgets() async {
    await HomeWidget.updateWidget(
      name: _widgetName,
      iOSName: _widgetName,
      androidName: _androidWidgetName,
    );
  }
}