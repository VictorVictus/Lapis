import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:to_do_app/services/user_service.dart';

class DashboardTabIndex extends Notifier<int> {
  @override
  int build() => 0;
  
  void setIndex(int index) {
    state = index;
  }
}

final dashboardTabIndexProvider = NotifierProvider<DashboardTabIndex, int>(DashboardTabIndex.new);

class IsUploading extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setStatus(bool status) {
    state = status;
  }
}

final isUploadingProfilePicProvider = NotifierProvider<IsUploading, bool>(IsUploading.new);

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';
  
  void setQuery(String query) {
    state = query;
  }
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(SearchQuery.new);

class DashboardController extends Notifier<void> {
  Timer? _debounceTimer;

  @override
  void build() {
    ref.onDispose(() => _debounceTimer?.cancel());
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).setQuery(query);
    });
  }

  Future<void> pickAndUploadImage(String userId) async {
    ref.read(isUploadingProfilePicProvider.notifier).setStatus(true);
    try {
      await ref.read(userServiceProvider).pickAndUploadImage(userId);
    } catch (e) {
      // Errors would typically be piped through an error provider
      throw e;
    } finally {
      ref.read(isUploadingProfilePicProvider.notifier).setStatus(false);
    }
  }
}

class Celebration extends Notifier<int> {
  @override
  int build() => 0;
  
  void trigger() {
    state++;
  }
}

final celebrationProvider = NotifierProvider<Celebration, int>(Celebration.new);

final dashboardControllerProvider = NotifierProvider<DashboardController, void>(DashboardController.new);


