import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:to_do_app/models/task.dart';

final statisticsServiceProvider = Provider<StatisticsService>((ref) => StatisticsService());

class DailyStats {
  final DateTime date;
  final int completed;

  DailyStats({required this.date, required this.completed});
}

class MonthlyStats {
  final String label;
  final int count;

  MonthlyStats({required this.label, required this.count});
}

class StatisticsData {
  final int totalCompleted;
  final int totalTasks;
  final int currentStreak;
  final int bestStreak;
  final List<DailyStats> dailyCompletions;
  final Map<String, int> byCategory;
  final Map<String, int> byPriority;
  final double overdueRate;
  final double avgCompletionHours;
  final Map<int, int> weekdayDistribution;
  final List<MonthlyStats> monthlyTrend;

  StatisticsData({
    required this.totalCompleted,
    required this.totalTasks,
    required this.currentStreak,
    required this.bestStreak,
    required this.dailyCompletions,
    required this.byCategory,
    required this.byPriority,
    required this.overdueRate,
    required this.avgCompletionHours,
    required this.weekdayDistribution,
    required this.monthlyTrend,
  });
}

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<StatisticsData> getStats(String userId) async {
    final tasksSnapshot = await _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .get();

    final tasks = tasksSnapshot.docs
        .map((doc) => Task.fromMap(doc.data(), doc.id))
        .toList();

    final completed = tasks.where((t) => t.status == TaskStatus.fulfilled).toList();
    final totalCompleted = completed.length;
    final totalTasks = tasks.length;

    final daily = _computeDailyCompletions(completed);
    final streak = _computeStreak(daily);
    final byCat = _byCategory(tasks);
    final byPri = _byPriority(tasks);
    final overdue = _computeOverdueRate(completed);
    final avgHours = _computeAvgCompletionHours(completed);
    final weekdays = _computeWeekdayDistribution(completed);
    final monthly = _computeMonthlyTrend(completed);

    return StatisticsData(
      totalCompleted: totalCompleted,
      totalTasks: totalTasks,
      currentStreak: streak.current,
      bestStreak: streak.best,
      dailyCompletions: _last7Days(daily),
      byCategory: byCat,
      byPriority: byPri,
      overdueRate: overdue,
      avgCompletionHours: avgHours,
      weekdayDistribution: weekdays,
      monthlyTrend: monthly,
    );
  }

  Map<DateTime, int> _computeDailyCompletions(List<Task> completed) {
    final map = <DateTime, int>{};
    for (final task in completed) {
      final day = task.completedAt ?? task.createdAt;
      final date = DateTime(day.year, day.month, day.day);
      map[date] = (map[date] ?? 0) + 1;
    }
    return map;
  }

  ({int current, int best}) _computeStreak(Map<DateTime, int> daily) {
    final sorted = daily.keys.toList()..sort((a, b) => b.compareTo(a));
    if (sorted.isEmpty) return (current: 0, best: 0);

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int current = 0;
    var checkDate = todayDate;
    while (daily.containsKey(checkDate)) {
      current++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    int best = 0;
    int run = 0;
    final allDates = daily.keys.toList()..sort();
    for (int i = 0; i < allDates.length; i++) {
      if (i == 0 || allDates[i].difference(allDates[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }

    return (current: current, best: best);
  }

  List<DailyStats> _last7Days(Map<DateTime, int> daily) {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final date = DateTime(today.year, today.month, today.day - (6 - i));
      return DailyStats(
        date: date,
        completed: daily[date] ?? 0,
      );
    });
  }

  Map<String, int> _byCategory(List<Task> tasks) {
    final map = <String, int>{};
    for (final task in tasks) {
      final name = task.category.name;
      map[name] = (map[name] ?? 0) + 1;
    }
    if (map.isEmpty) map['General'] = 0;
    return map;
  }

  Map<String, int> _byPriority(List<Task> tasks) {
    final map = <String, int>{};
    for (final task in tasks) {
      final name = task.priority.displayName;
      map[name] = (map[name] ?? 0) + 1;
    }
    return map;
  }

  double _computeOverdueRate(List<Task> completed) {
    int overdue = 0;
    int withDeadline = 0;
    for (final task in completed) {
      if (task.deadline != null) {
        withDeadline++;
        final completedDate = task.completedAt ?? task.createdAt;
        if (completedDate.isAfter(task.deadline!)) {
          overdue++;
        }
      }
    }
    return withDeadline > 0 ? overdue / withDeadline : 0.0;
  }

  double _computeAvgCompletionHours(List<Task> completed) {
    if (completed.isEmpty) return 0.0;
    double totalHours = 0;
    int count = 0;
    for (final task in completed) {
      if (task.completedAt != null) {
        final diff = task.completedAt!.difference(task.createdAt);
        totalHours += diff.inMinutes / 60.0;
        count++;
      }
    }
    return count > 0 ? totalHours / count : 0.0;
  }

  Map<int, int> _computeWeekdayDistribution(List<Task> completed) {
    final map = <int, int>{};
    for (final task in completed) {
      final day = task.completedAt ?? task.createdAt;
      final wd = day.weekday; // 1=Mon .. 7=Sun
      map[wd] = (map[wd] ?? 0) + 1;
    }
    return map;
  }

  List<MonthlyStats> _computeMonthlyTrend(List<Task> completed) {
    final map = <String, int>{};
    for (final task in completed) {
      final day = task.completedAt ?? task.createdAt;
      final key = DateFormat('MMM yyyy').format(day);
      map[key] = (map[key] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => _monthYearKey(a.key).compareTo(_monthYearKey(b.key)));
    return sorted.map((e) => MonthlyStats(label: e.key, count: e.value)).toList();
  }

  int _monthYearKey(String label) {
    try {
      return DateFormat('MMM yyyy').parse(label).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }
}
