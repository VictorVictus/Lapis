import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/services/demo_statistics_service.dart';

class UseDemoStatsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enable() => state = true;
  void disable() => state = false;
}

final useDemoStatsProvider = NotifierProvider<UseDemoStatsNotifier, bool>(UseDemoStatsNotifier.new);

class DemoPresetNotifier extends Notifier<DemoPreset> {
  @override
  DemoPreset build() => DemoPreset.normal;

  void set(DemoPreset preset) => state = preset;
}

final demoPresetProvider = NotifierProvider<DemoPresetNotifier, DemoPreset>(DemoPresetNotifier.new);

final demoStatisticsServiceProvider = Provider<DemoStatisticsService>((ref) => DemoStatisticsService());
