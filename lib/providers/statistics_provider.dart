import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/services/statistics_service.dart';

final statisticsProvider = FutureProvider.family<StatisticsData, String>((ref, userId) {
  return ref.read(statisticsServiceProvider).getStats(userId);
});
