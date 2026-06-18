import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/models/subclasses/group_task.dart';
import 'package:to_do_app/services/sync_coordinator.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService(ref));

class GroupService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GroupService(this._ref);

  String _generateInviteCode() {
    final rand = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final parts = List.generate(2, (_) =>
      List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join()
    );
    return parts.join('-');
  }

  Stream<List<Group>> getGroups(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((snap) async {
      final data = snap.data();
      final groupIds = (data?['groupIds'] as List<dynamic>?)?.cast<String>() ?? [];
      if (groupIds.isEmpty) return [];
      final groups = await Future.wait(
        groupIds.map((id) async {
          final doc = await _firestore.collection('groups').doc(id).get();
          return doc.exists ? Group.fromMap(doc.data()!, doc.id) : null;
        }),
      );
      return groups.whereType<Group>().toList();
    });
  }

  Future<Group> createGroup(String name, String userId, String username, {String? description}) async {
    final ref = _firestore.collection('groups').doc();
    final code = _generateInviteCode();
    final now = DateTime.now();

    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore.runTransaction((tx) async {
        tx.set(ref, {
          'name': name,
          'description': description,
          'createdBy': userId,
          'inviteCode': code,
          'createdAt': Timestamp.fromDate(now),
          'memberCount': 1,
        });
        tx.set(ref.collection('members').doc(userId), {
          'role': 'admin',
          'joinedAt': Timestamp.fromDate(now),
          'username': username,
        });
        tx.update(_firestore.collection('users').doc(userId), {
          'groupIds': FieldValue.arrayUnion([ref.id]),
        });
      });
    });

    return Group(
      id: ref.id,
      name: name,
      description: description,
      createdBy: userId,
      inviteCode: code,
      createdAt: now,
      memberCount: 1,
    );
  }

  Future<String?> joinByCode(String code, String userId, String username) async {
    final trimmed = code.trim().toUpperCase();
    final snapshot = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final groupDoc = snapshot.docs.first;
    final groupId = groupDoc.id;

    final existing = await groupDoc.reference.collection('members').doc(userId).get();
    if (existing.exists) return groupId;

    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore.runTransaction((tx) async {
        tx.set(groupDoc.reference.collection('members').doc(userId), {
          'role': 'member',
          'joinedAt': Timestamp.fromDate(DateTime.now()),
          'username': username,
        });
        tx.update(groupDoc.reference, {
          'memberCount': FieldValue.increment(1),
        });
        tx.update(_firestore.collection('users').doc(userId), {
          'groupIds': FieldValue.arrayUnion([groupId]),
        });
      });
    });

    return groupId;
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      final ref = _firestore.collection('groups').doc(groupId);
      await _firestore.runTransaction((tx) async {
        tx.delete(ref.collection('members').doc(userId));
        tx.update(ref, {'memberCount': FieldValue.increment(-1)});
        tx.update(_firestore.collection('users').doc(userId), {
          'groupIds': FieldValue.arrayRemove([groupId]),
        });
      });
    });
  }

  Stream<GroupMember?> memberStream(String groupId, String uid) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      return data != null ? GroupMember.fromMap(data, snap.id) : null;
    });
  }

  Stream<List<GroupMember>> membersStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupMember.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<String> regenerateInviteCode(String groupId, String userId) async {
    final code = _generateInviteCode();
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore.collection('groups').doc(groupId).update({'inviteCode': code});
    });
    return code;
  }

  Stream<List<GroupTask>> tasksStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('tasks')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupTask.fromMap(doc.data(), doc.id, groupId: groupId))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
  }

  Future<void> createTask(GroupTask task) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('groups')
          .doc(task.groupId)
          .collection('tasks')
          .doc(task.id)
          .set(task.toMap());
    });
  }

  Future<void> updateTask(GroupTask task) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      final map = task.toMap();
      map.remove('createdBy');
      map.remove('createdAt');
      await _firestore
          .collection('groups')
          .doc(task.groupId)
          .collection('tasks')
          .doc(task.id)
          .update(map);
    });
  }

  Future<void> deleteTask(String groupId, String taskId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasks')
          .doc(taskId)
          .delete();
    });
  }

  String generateTaskId(String groupId) {
    return _firestore.collection('groups').doc(groupId).collection('tasks').doc().id;
  }

  Stream<List<GroupSubTask>> subTasksStream(String groupId, String taskId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('tasks')
        .doc(taskId)
        .collection('subtasks')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupSubTask.fromMap(doc.data(), doc.id, groupTaskId: taskId))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
  }

  Future<void> createSubTask(GroupSubTask subTask, String groupId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasks')
          .doc(subTask.groupTaskId)
          .collection('subtasks')
          .doc(subTask.id)
          .set(subTask.toMap());
    });
  }

  Future<void> updateSubTask(GroupSubTask subTask, String groupId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasks')
          .doc(subTask.groupTaskId)
          .collection('subtasks')
          .doc(subTask.id)
          .update(subTask.toMap());
    });
  }

  Future<void> deleteSubTask(String groupId, String taskId, String subTaskId) async {
    await _ref.read(syncCoordinatorProvider).runWithSyncStatus(() async {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('tasks')
          .doc(taskId)
          .collection('subtasks')
          .doc(subTaskId)
          .delete();
    });
  }
}
