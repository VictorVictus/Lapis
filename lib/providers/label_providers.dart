import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/label.dart';
import 'package:to_do_app/services/label_service.dart';

final userLabelsProvider = StreamProvider.family<List<Label>, String>((ref, userId) {
  return ref.read(labelServiceProvider).getLabels(userId);
});

final labelsCacheProvider = Provider.family<Map<String, Label>, String>((ref, userId) {
  final labelsAsync = ref.watch(userLabelsProvider(userId));
  return labelsAsync.when(
    data: (labels) => {for (final l in labels) l.id: l},
    loading: () => const {},
    error: (_, __) => const {},
  );
});
