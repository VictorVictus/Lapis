import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:to_do_app/models/task.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Initialize Timezones (Only on Native platforms)
    if (!kIsWeb) {
      tz.initializeTimeZones();
      try {
        final String timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('Could not get local timezone, falling back to UTC: $e');
      }
    }

    // 2. Android Settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS Settings
    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // 4. General Settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap logic here if needed
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleTaskNotification(Task task) async {
    if (kIsWeb || task.scheduledAt == null) return;

    // Don't schedule if date is in the past
    if (task.scheduledAt!.isBefore(DateTime.now())) return;

    final String channelId = 'task_reminders';
    final String channelName = 'Task Reminders';
    final String channelDescription = 'Notifications for task deadlines and reminders';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    final DarwinNotificationDetails darwinDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    // Generate a unique ID from the task ID (hash)
    final int notificationId = task.id.hashCode.abs();

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Reminder: ${task.title}',
      task.notes?.isNotEmpty == true ? task.notes : 'You have a task scheduled now!',
      tz.TZDateTime.from(task.scheduledAt!, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.id,
    );
  }

  Future<void> cancelNotification(String taskId) async {
    if (kIsWeb) return;
    final int notificationId = taskId.hashCode.abs();
    await _notificationsPlugin.cancel(notificationId);
  }
}
