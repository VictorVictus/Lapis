import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/demo_statistics_provider.dart';
import 'package:to_do_app/services/statistics_service.dart';

final statisticsProvider = FutureProvider.family<StatisticsData, String>((ref, userId) {
  if (kDebugMode && ref.watch(useDemoStatsProvider)) {
    final preset = ref.watch(demoPresetProvider);
    return ref.read(demoStatisticsServiceProvider).getStats(userId, preset);
  }
  return ref.read(statisticsServiceProvider).getStats(userId);
});
