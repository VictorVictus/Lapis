import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/services/group_service.dart';

final groupMembersCacheProvider = StreamProvider.family<Map<String, List<GroupMember>>, String>((ref, userId) {
  final groupService = ref.read(groupServiceProvider);
  final controller = StreamController<Map<String, List<GroupMember>>>();

  final result = <String, List<GroupMember>>{};
  final subs = <StreamSubscription>[];

  groupService.getGroups(userId).listen((groups) {
    for (final s in subs) { s.cancel(); }
    subs.clear();
    result.clear();
    for (final g in groups) {
      final sub = groupService.membersStream(g.id).listen((members) {
        result[g.id] = List.from(members);
        controller.add(Map.from(result));
      });
      subs.add(sub);
    }
    controller.add(Map.from(result));
  });

  ref.onDispose(() {
    for (final s in subs) { s.cancel(); }
    controller.close();
  });

  return controller.stream;
});
