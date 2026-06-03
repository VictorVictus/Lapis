import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls the maximum number of tasks fetched per status tab.
/// Starts at 20 and increments by 20 each time the user scrolls to the bottom.
class TaskLimitNotifier extends Notifier<int> {
  static const int _pageSize = 20;

  @override
  int build() => _pageSize;

  void loadMore() {
    state = state + _pageSize;
  }

  void reset() {
    state = _pageSize;
  }
}

final taskLimitProvider = NotifierProvider<TaskLimitNotifier, int>(TaskLimitNotifier.new);
