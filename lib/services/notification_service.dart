import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Map<String, Future<void>> _subjectOps = <String, Future<void>>{};

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleResponse,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<bool> ensurePermissions() async {
    await init();
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final enabled = await androidPlugin.areNotificationsEnabled();
    if (enabled == true) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<void> scheduleSubjectReminders(
    Subject subject, {
    required String semesterKey,
  }) async {
    await _queueForSubject(subject.id, () async {
      final granted = await ensurePermissions();
      if (!granted) return;
      for (final entry in _reminderSlots(subject)) {
        final scheduled = _nextInstanceOfWeekday(
          entry.weekday,
          entry.slot.start,
          subject.reminderMinutes,
        );
        final id = _notificationId(subject.id, entry.weekday, entry.slotIndex);
        await _scheduleWithFallback(
          id: id,
          title: "Upcoming: ${subject.name}",
          body: "Starts at ${_formatTime(entry.slot.start)}",
          scheduled: scheduled,
          payload: _payload(
            subject.id,
            semesterKey,
            entry.weekday,
            entry.slotIndex,
          ),
          repeatWeekly: true,
        );
      }
    });
  }

  Future<void> sendTestNotificationNow() async {
    final granted = await ensurePermissions();
    if (!granted) return;
    await _plugin.show(
      999999,
      'Attendance Tracker',
      'Test notification is working.',
      _details(),
      payload: '',
    );
  }

  Future<void> sendScheduledTestIn30Seconds() async {
    final granted = await ensurePermissions();
    if (!granted) return;
    final scheduled = tz.TZDateTime.now(tz.local).add(
      const Duration(seconds: 30),
    );
    await _scheduleWithFallback(
      id: 999998,
      title: 'Attendance Tracker',
      body: 'Scheduled test fired.',
      scheduled: scheduled,
      payload: '',
      repeatWeekly: false,
    );
  }

  Future<int> pendingCount() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  Future<void> cancelSubjectReminders(Subject subject) async {
    await _queueForSubject(subject.id, () async {
      await init();
      for (final entry in _reminderSlots(subject)) {
        final id = _notificationId(subject.id, entry.weekday, entry.slotIndex);
        await _plugin.cancel(id);
      }
    });
  }

  tz.TZDateTime _nextInstanceOfWeekday(
    int weekday,
    TimeOfDay time,
    int reminderMinutes,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    var classTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (classTime.weekday != weekday || classTime.isBefore(now)) {
      classTime = classTime.add(const Duration(days: 1));
    }

    final reminderTime =
        classTime.subtract(Duration(minutes: reminderMinutes));
    // If reminders are enabled close to class time, fire once shortly instead
    // of silently scheduling next week's reminder.
    if (reminderTime.isBefore(now) &&
        classTime.weekday == now.weekday &&
        classTime.isAfter(now)) {
      return now.add(const Duration(seconds: 15));
    }
    return reminderTime;
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'attendance_reminders',
      'Attendance Reminders',
      channelDescription: 'Notifications before each lecture',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('present', 'Mark Present'),
        AndroidNotificationAction('absent', 'Mark Absent'),
      ],
    );
    return const NotificationDetails(android: android);
  }

  static Future<void> _handleResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload ?? '';
    if (payload.isEmpty) return;
    final parts = payload.split('|');
    if (parts.length != 4) return;

    final subjectId = parts[0];
    final semesterKey = parts[1];
    final weekday = int.tryParse(parts[2]) ?? 0;
    final slotIndex = int.tryParse(parts[3]) ?? -1;
    final actionId = response.actionId;

    if (weekday == 0 || slotIndex < 0) return;
    if (actionId != 'present' && actionId != 'absent') return;

    await Hive.initFlutter();
    final box = await Hive.openBox('timetableBox');
    final data = box.get(semesterKey, defaultValue: []);
    final subjects = (data as List)
        .map((e) => Subject.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final target = subjects.firstWhere(
      (s) => s.id == subjectId,
      orElse: () => Subject(name: '', weeklySchedule: {}),
    );
    if (target.name.isEmpty) return;

    final today = DateTime.now();
    if (today.weekday != weekday) return;
    if (slotIndex >= target.getSlotsFor(today).length) return;

    target.markAttendance(
      today,
      slotIndex,
      actionId == 'present'
          ? AttendanceStatus.present
          : AttendanceStatus.absent,
    );

    final updated = subjects.map((s) => s.toMap()).toList();
    await box.put(semesterKey, updated);
  }

  int _notificationId(String subjectId, int weekday, int slotIndex) {
    final stable = _stableHash(subjectId);
    return stable + (weekday * 100) + slotIndex;
  }

  int _stableHash(String input) {
    var hash = 0;
    for (final c in input.codeUnits) {
      hash = 31 * hash + c;
    }
    return hash.abs() % 100000;
  }

  String _payload(String subjectId, String semesterKey, int weekday, int slotIndex) {
    return '$subjectId|$semesterKey|$weekday|$slotIndex';
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required String payload,
    required bool repeatWeekly,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents:
            repeatWeekly ? DateTimeComponents.dayOfWeekAndTime : null,
        payload: payload,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents:
            repeatWeekly ? DateTimeComponents.dayOfWeekAndTime : null,
        payload: payload,
      );
    }
  }

  Future<void> _queueForSubject(
    String subjectId,
    Future<void> Function() action,
  ) {
    final previous = _subjectOps[subjectId] ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) => action());
    _subjectOps[subjectId] = next.whenComplete(() {
      if (identical(_subjectOps[subjectId], next)) {
        _subjectOps.remove(subjectId);
      }
    });
    return next;
  }

  List<_ReminderSlotEntry> _reminderSlots(Subject subject) {
    if (!subject.isHourWise) {
      final entries = <_ReminderSlotEntry>[];
      for (final weekly in subject.weeklySchedule.entries) {
        for (var i = 0; i < weekly.value.length; i++) {
          entries.add(
            _ReminderSlotEntry(
              weekday: weekly.key,
              slotIndex: i,
              slot: weekly.value[i],
            ),
          );
        }
      }
      return entries;
    }

    final entries = <_ReminderSlotEntry>[];
    for (final weekly in subject.weeklyHours.entries) {
      if (weekly.value <= 0) continue;
      final endHour = (9 + weekly.value).clamp(0, 23).toInt();
      entries.add(
        _ReminderSlotEntry(
          weekday: weekly.key,
          slotIndex: 0,
          slot: LectureSlot(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: endHour, minute: 0),
          ),
        ),
      );
    }
    return entries;
  }
}

class _ReminderSlotEntry {
  final int weekday;
  final int slotIndex;
  final LectureSlot slot;

  _ReminderSlotEntry({
    required this.weekday,
    required this.slotIndex,
    required this.slot,
  });
}
