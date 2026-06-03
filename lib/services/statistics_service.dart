import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/task.dart';

final statisticsServiceProvider = Provider<StatisticsService>((ref) => StatisticsService());

class DailyStats {
  final DateTime date;
  final int completed;

  DailyStats({required this.date, required this.completed});
}

class StatisticsData {
  final int totalCompleted;
  final int totalTasks;
  final int currentStreak;
  final int bestStreak;
  final List<DailyStats> dailyCompletions;
  final Map<String, int> byCategory;
  final Map<String, int> byPriority;

  StatisticsData({
    required this.totalCompleted,
    required this.totalTasks,
    required this.currentStreak,
    required this.bestStreak,
    required this.dailyCompletions,
    required this.byCategory,
    required this.byPriority,
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

    return StatisticsData(
      totalCompleted: totalCompleted,
      totalTasks: totalTasks,
      currentStreak: streak.current,
      bestStreak: streak.best,
      dailyCompletions: _last7Days(daily),
      byCategory: byCat,
      byPriority: byPri,
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
      final name = task.priority.name;
      map[name] = (map[name] ?? 0) + 1;
    }
    return map;
  }
}
