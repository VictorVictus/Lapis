import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/core/firebase_bootstrap.dart';
import 'package:to_do_app/widgets/error_boundary_widget.dart';
import 'dart:developer';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:to_do_app/services/fcm_service.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/services/share_service.dart';
import 'package:to_do_app/services/voice_service.dart';
import 'package:to_do_app/services/voice_task_parser.dart';
import 'package:to_do_app/services/widget_data_service.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/models/subclasses/label.dart';
import 'package:to_do_app/models/subclasses/section.dart';
import 'package:to_do_app/models/subclasses/group.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ErrorBoundaryWidget(errorDetails: errorDetails),
      ),
    );
  };

  if (kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      log('Framework error caught: ${details.exceptionAsString()}');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log('Async error caught: $error', error: error, stackTrace: stack);
      return true;
    };
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureFirebaseProductionServices();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final fcmService = FcmService();
  await fcmService.initialize();

  ShareService.init();

  await WidgetDataService.initialize();

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } else {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  // Voice-first: if launched by OK Google, process headlessly and finish.
  final voiceText = await VoiceService.checkForPendingCommand();
  if (voiceText != null) {
    await _processVoiceHeadless(voiceText);
    return;
  }

  runApp(const ProviderScope(child: App()));
}

Future<void> _processVoiceHeadless(String raw) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final categories = await _loadCategories(uid);
    if (categories.isEmpty) return;

    final labels = await _loadLabels(uid);
    final sections = await _loadSections(uid);
    final groups = await _loadGroups(uid);

    final parsed = parseVoiceCommand(
      raw,
      categories: categories,
      labels: labels,
      sections: sections,
      groups: groups,
    );

    if (parsed.isEmpty) return;

    for (final task in parsed) {
      final fbTask = Task(
        id: FirebaseFirestore.instance.collection('tasks').doc().id,
        userId: uid,
        title: task.title,
        category: task.category ?? categories.first,
        priority: task.priority,
        order: DateTime.now().millisecondsSinceEpoch.toDouble(),
        scheduledAt: task.scheduledAt,
        deadline: task.deadline,
        pinned: task.pinned,
        notes: task.notes,
        type: task.recurrentConfig != null ? TaskType.recurrent : TaskType.oneTime,
        recurrentConfig: task.recurrentConfig,
        labelIds: task.labels.map((l) => l.id).toList(),
        createdAt: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(fbTask.id)
          .set(fbTask.toMap());
    }

    final msg = parsed.length == 1
        ? 'Created: ${parsed.first.title}'
        : 'Created ${parsed.length} tasks';
    await VoiceService.showToast(msg);
  } catch (e) {
    await VoiceService.showToast('Failed to create task');
  } finally {
    await VoiceService.finishActivity();
  }
}

Future<List<TaskCategory>> _loadCategories(String uid) async {
  final snap = await FirebaseFirestore.instance
      .collection('categories')
      .where('userId', isEqualTo: uid)
      .get();
  return snap.docs.map((doc) => TaskCategory.fromMap(doc.data())).toList();
}

Future<List<Label>> _loadLabels(String uid) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('labels')
      .get();
  return snap.docs.map((doc) => Label.fromMap(doc.data(), doc.id)).toList();
}

Future<List<Section>> _loadSections(String uid) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('sections')
      .orderBy('order')
      .get();
  return snap.docs.map((doc) => Section.fromMap(doc.data(), doc.id)).toList();
}

Future<List<Group>> _loadGroups(String uid) async {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  final groupIds = (userDoc.data()?['groupIds'] as List<dynamic>?)?.cast<String>() ?? [];
  if (groupIds.isEmpty) return [];
  final snapshots = await Future.wait(
    groupIds.map((id) =>
        FirebaseFirestore.instance.collection('groups').doc(id).get()),
  );
  return snapshots
      .where((doc) => doc.exists)
      .map((doc) => Group.fromMap(doc.data()!, doc.id))
      .toList();
}

