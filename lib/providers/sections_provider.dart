import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/section.dart';
import 'package:to_do_app/services/section_service.dart';

final userSectionsProvider = StreamProvider.family<List<Section>, String>((ref, userId) {
  return ref.read(sectionServiceProvider).getSections(userId);
});
