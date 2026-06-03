import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';

const _filtersKey = 'enabled_smart_filters';

final smartFiltersProvider =
    NotifierProvider<SmartFiltersNotifier, Set<SmartFilter>>(
  SmartFiltersNotifier.new,
);

class SmartFiltersNotifier extends Notifier<Set<SmartFilter>> {
  @override
  Set<SmartFilter> build() => {};

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_filtersKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<int>();
    final saved = list
        .map((i) => SmartFilter.values.firstWhere(
              (f) => f.index == i,
              orElse: () => SmartFilter.today,
            ))
        .where((f) => f != SmartFilter.all)
        .toSet();
    state = saved;
  }

  Future<void> toggle(SmartFilter filter) async {
    if (filter == SmartFilter.all) return;
    final next = Set<SmartFilter>.from(state);
    if (next.contains(filter)) {
      next.remove(filter);
    } else {
      next.add(filter);
    }
    state = next;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.map((f) => f.index).toList());
    await prefs.setString(_filtersKey, raw);
  }
}
