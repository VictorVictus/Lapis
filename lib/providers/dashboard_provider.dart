import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ViewMode { list, kanban }

enum GroupBy { none, category, priority, section }

enum SortBy { order, deadline, priority, created }

enum SmartFilter { all, today, thisWeek, overdue, highPriority, hasDeadline, noDeadline, thisMonth, recurring }

class DashboardState {
  final int tabIndex;
  final String searchQuery;
  final bool searchMode;
  final int celebrationTrigger;
  final ViewMode viewMode;
  final GroupBy groupBy;
  final SortBy sortBy;
  final SmartFilter smartFilter;
  final bool selectionMode;
  final Set<String> selectedTaskIds;

  DashboardState({
    this.tabIndex = 0,
    this.searchQuery = '',
    this.searchMode = false,
    this.celebrationTrigger = 0,
    this.viewMode = ViewMode.list,
    this.groupBy = GroupBy.none,
    this.sortBy = SortBy.order,
    this.smartFilter = SmartFilter.all,
    this.selectionMode = false,
    this.selectedTaskIds = const {},
  });

  DashboardState copyWith({
    int? tabIndex,
    String? searchQuery,
    bool? searchMode,
    int? celebrationTrigger,
    ViewMode? viewMode,
    GroupBy? groupBy,
    SortBy? sortBy,
    SmartFilter? smartFilter,
    bool? selectionMode,
    Set<String>? selectedTaskIds,
  }) {
    return DashboardState(
      tabIndex: tabIndex ?? this.tabIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMode: searchMode ?? this.searchMode,
      celebrationTrigger: celebrationTrigger ?? this.celebrationTrigger,
      viewMode: viewMode ?? this.viewMode,
      groupBy: groupBy ?? this.groupBy,
      sortBy: sortBy ?? this.sortBy,
      smartFilter: smartFilter ?? this.smartFilter,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedTaskIds: selectedTaskIds ?? this.selectedTaskIds,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    return DashboardState();
  }

  void setTabIndex(int index) {
    state = state.copyWith(tabIndex: index);
  }

  void setSearchMode(bool enabled) {
    state = state.copyWith(searchMode: enabled, searchQuery: enabled ? state.searchQuery : '');
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void triggerCelebration() {
    state = state.copyWith(celebrationTrigger: state.celebrationTrigger + 1);
  }

  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == ViewMode.list ? ViewMode.kanban : ViewMode.list,
    );
  }

  void setGroupBy(GroupBy groupBy) {
    state = state.copyWith(groupBy: groupBy);
  }

  void setSmartFilter(SmartFilter filter) {
    state = state.copyWith(smartFilter: filter);
  }

  void setSortBy(SortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void toggleSelectionMode() {
    final next = !state.selectionMode;
    state = state.copyWith(selectionMode: next, selectedTaskIds: next ? state.selectedTaskIds : {});
  }

  void toggleTaskSelection(String taskId) {
    final ids = Set<String>.from(state.selectedTaskIds);
    if (ids.contains(taskId)) {
      ids.remove(taskId);
    } else {
      ids.add(taskId);
    }
    state = state.copyWith(selectedTaskIds: ids);
  }

  void selectAll(List<String> taskIds) {
    state = state.copyWith(selectedTaskIds: Set.from(taskIds));
  }

  void clearSelection() {
    state = state.copyWith(selectionMode: false, selectedTaskIds: {});
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
