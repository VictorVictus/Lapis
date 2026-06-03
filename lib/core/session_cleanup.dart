import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/pagination_provider.dart';
import 'package:to_do_app/providers/sync_provider.dart';

/// Clears in-memory UI state when the user signs out.
void invalidateSessionProviders(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(taskLimitProvider);
  ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.idle);
  ref.read(lastSyncErrorProvider.notifier).setError(null);
  ref.read(showSuccessIndicatorProvider.notifier).setVisible(false);
}
