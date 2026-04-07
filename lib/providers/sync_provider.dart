import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus { idle, syncing, error }

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;
  
  void setStatus(SyncStatus status) => state = status;
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

class LastSyncErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  
  void setError(String? error) => state = error;
}

final lastSyncErrorProvider = NotifierProvider<LastSyncErrorNotifier, String?>(LastSyncErrorNotifier.new);

class ShowSuccessIndicatorNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setVisible(bool visible) => state = visible;
}

final showSuccessIndicatorProvider = NotifierProvider<ShowSuccessIndicatorNotifier, bool>(ShowSuccessIndicatorNotifier.new);
