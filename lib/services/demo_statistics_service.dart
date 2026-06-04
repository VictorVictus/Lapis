import 'package:to_do_app/services/statistics_service.dart';

enum DemoPreset { normal, overflow, zero, sparse, extreme }

class DemoStatisticsService {
  StatisticsData getStats(String userId, DemoPreset preset) {
    switch (preset) {
      case DemoPreset.normal:
        return _normal();
      case DemoPreset.overflow:
        return _overflow();
      case DemoPreset.zero:
        return _zero();
      case DemoPreset.sparse:
        return _sparse();
      case DemoPreset.extreme:
        return _extreme();
    }
  }

  StatisticsData _normal() => StatisticsData(
        totalCompleted: 30,
        totalTasks: 50,
        currentStreak: 12,
        bestStreak: 20,
        dailyCompletions: [
          DailyStats(date: DateTime.now().subtract(const Duration(days: 6)), completed: 3),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 5)), completed: 5),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 4)), completed: 2),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 3)), completed: 7),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 2)), completed: 4),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 1)), completed: 6),
          DailyStats(date: DateTime.now(), completed: 3),
        ],
        byCategory: {
          'General': 15,
          'Work': 10,
          'Personal': 8,
          'Shopping': 5,
          'Health': 2,
        },
        byPriority: {
          'none': 20,
          'low': 10,
          'medium': 12,
          'high': 8,
        },
        overdueRate: 0.35,
        avgCompletionHours: 4.5,
        weekdayDistribution: {
          1: 8, 2: 6, 3: 7, 4: 5, 5: 9, 6: 3, 7: 2,
        },
        monthlyTrend: [
          MonthlyStats(label: 'Mar 2026', count: 8),
          MonthlyStats(label: 'Apr 2026', count: 12),
          MonthlyStats(label: 'May 2026', count: 10),
        ],
      );

  StatisticsData _overflow() => StatisticsData(
        totalCompleted: 100,
        totalTasks: 150,
        currentStreak: 45,
        bestStreak: 60,
        dailyCompletions: [
          DailyStats(date: DateTime.now().subtract(const Duration(days: 6)), completed: 12),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 5)), completed: 18),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 4)), completed: 9),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 3)), completed: 22),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 2)), completed: 15),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 1)), completed: 20),
          DailyStats(date: DateTime.now(), completed: 14),
        ],
        byCategory: {
          'General': 30,
          'This is an extremely long category name that might overflow the layout': 25,
          'Work / Professional / Office Tasks': 20,
          'Personal Errands & Chores': 15,
          'Shopping List (Grocery, Electronics, Clothes)': 10,
          'Health & Fitness & Wellness': 8,
          'Learning & Development & Courses': 7,
          'Finance & Budgeting & Bills': 6,
          'Travel Planning & Trips': 5,
          'Home Improvement & DIY Projects': 4,
          'Social Events & Meetups & Parties': 3,
          'Miscellaneous Very Long Category That Keeps Going': 2,
        },
        byPriority: {
          'none': 50,
          'low': 30,
          'medium': 40,
          'high': 30,
        },
        overdueRate: 0.89,
        avgCompletionHours: 72.3,
        weekdayDistribution: {
          1: 20, 2: 18, 3: 22, 4: 15, 5: 25, 6: 10, 7: 8,
        },
        monthlyTrend: [
          MonthlyStats(label: 'Jan 2026', count: 12),
          MonthlyStats(label: 'Feb 2026', count: 15),
          MonthlyStats(label: 'Mar 2026', count: 10),
          MonthlyStats(label: 'Apr 2026', count: 18),
          MonthlyStats(label: 'May 2026', count: 22),
          MonthlyStats(label: 'Jun 2026', count: 14),
        ],
      );

  StatisticsData _zero() => StatisticsData(
        totalCompleted: 0,
        totalTasks: 0,
        currentStreak: 0,
        bestStreak: 0,
        dailyCompletions: [
          DailyStats(date: DateTime.now().subtract(const Duration(days: 6)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 5)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 4)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 3)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 2)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 1)), completed: 0),
          DailyStats(date: DateTime.now(), completed: 0),
        ],
        byCategory: {},
        byPriority: {},
        overdueRate: 0.0,
        avgCompletionHours: 0.0,
        weekdayDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0},
        monthlyTrend: [],
      );

  StatisticsData _sparse() => StatisticsData(
        totalCompleted: 1,
        totalTasks: 3,
        currentStreak: 1,
        bestStreak: 1,
        dailyCompletions: [
          DailyStats(date: DateTime.now().subtract(const Duration(days: 6)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 5)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 4)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 3)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 2)), completed: 0),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 1)), completed: 0),
          DailyStats(date: DateTime.now(), completed: 1),
        ],
        byCategory: {'General': 1},
        byPriority: {'none': 1},
        overdueRate: 1.0,
        avgCompletionHours: 0.5,
        weekdayDistribution: {7: 1},
        monthlyTrend: [
          MonthlyStats(label: 'Jun 2026', count: 1),
        ],
      );

  StatisticsData _extreme() => StatisticsData(
        totalCompleted: 999,
        totalTasks: 1000,
        currentStreak: 365,
        bestStreak: 365,
        dailyCompletions: [
          DailyStats(date: DateTime.now().subtract(const Duration(days: 6)), completed: 150),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 5)), completed: 142),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 4)), completed: 138),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 3)), completed: 155),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 2)), completed: 148),
          DailyStats(date: DateTime.now().subtract(const Duration(days: 1)), completed: 160),
          DailyStats(date: DateTime.now(), completed: 106),
        ],
        byCategory: {
          'Work': 400,
          'Personal': 300,
          'Health': 200,
          'Finance': 99,
        },
        byPriority: {
          'none': 200,
          'low': 200,
          'medium': 300,
          'high': 300,
        },
        overdueRate: 1.0,
        avgCompletionHours: 0.05,
        weekdayDistribution: {
          1: 180, 2: 160, 3: 175, 4: 155, 5: 190, 6: 80, 7: 59,
        },
        monthlyTrend: [
          MonthlyStats(label: 'Jan 2026', count: 85),
          MonthlyStats(label: 'Feb 2026', count: 78),
          MonthlyStats(label: 'Mar 2026', count: 92),
          MonthlyStats(label: 'Apr 2026', count: 88),
          MonthlyStats(label: 'May 2026', count: 95),
          MonthlyStats(label: 'Jun 2026', count: 90),
        ],
      );
}
