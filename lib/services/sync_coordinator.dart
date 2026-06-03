import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/sync_provider.dart';

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(ref);
});

/// Runs mutations with sync UI state. Allows Firestore offline persistence
/// to queue writes instead of failing when the device has no connectivity.
class SyncCoordinator {
  SyncCoordinator(this._ref);

  final Ref _ref;
  Timer? _successIndicatorTimer;

  Future<void> runWithSyncStatus(
    Future<void> Function() action, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
    _successIndicatorTimer?.cancel();

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none);

      if (isOffline) {
        await action();
      } else {
        await action().timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'Connection timeout: Server is too slow.',
          ),
        );
      }

      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.idle);
      _ref.read(lastSyncErrorProvider.notifier).setError(null);
      _ref.read(showSuccessIndicatorProvider.notifier).setVisible(true);

      _successIndicatorTimer = Timer(const Duration(seconds: 3), () {
        if (!_ref.mounted) return;
        _ref.read(showSuccessIndicatorProvider.notifier).setVisible(false);
      });
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
      _ref.read(lastSyncErrorProvider.notifier).setError(_messageFor(e));
      rethrow;
    }
  }

  String _messageFor(Object error) {
    if (error is TimeoutException) {
      return error.message ?? 'Connection timed out.';
    }
    return error.toString();
  }
}
