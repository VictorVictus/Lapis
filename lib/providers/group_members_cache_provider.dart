import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/services/group_service.dart';

final groupMembersCacheProvider = StreamProvider.family<Map<String, List<GroupMember>>, String>((ref, userId) {
  final groupService = ref.read(groupServiceProvider);

  return groupService.getGroups(userId).asyncMap((groups) async {
    final result = <String, List<GroupMember>>{};
    for (final g in groups) {
      final members = await groupService.membersStream(g.id).first;
      result[g.id] = members;
    }
    return result;
  });
});
