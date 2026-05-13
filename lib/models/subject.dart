import 'package:flutter/material.dart';
import 'dart:math' as math;

class LectureSlot {
  TimeOfDay start;
  TimeOfDay end;

  LectureSlot({required this.start, required this.end});

  String format(BuildContext context) =>
      "${start.format(context)} - ${end.format(context)}";

  Map<String, dynamic> toMap() => {
    'startHour': start.hour,
    'startMinute': start.minute,
    'endHour': end.hour,
    'endMinute': end.minute,
  };

  factory LectureSlot.fromMap(Map<String, dynamic> map) {
    return LectureSlot(
      start: TimeOfDay(hour: map['startHour'], minute: map['startMinute']),
      end: TimeOfDay(hour: map['endHour'], minute: map['endMinute']),
    );
  }
}

enum AttendanceStatus { present, absent, cancelled }

class Subject {
  String id;
  String name;
  String subjectCode;
  String instructorName;
  Map<int, List<LectureSlot>> weeklySchedule;
  Map<DateTime, List<AttendanceStatus?>> attendance = {};
  Map<DateTime, List<LectureSlot>> rescheduledLectures = {};
  Map<DateTime, List<DateTime>> _originalDates = {};
  int updatedAt;
  double goalPercent;
  bool remindersEnabled;
  int reminderMinutes;
  int carryPresent;
  int carryAbsent;
  bool isHourWise;
  Map<int, int> weeklyHours;

  Subject({
    String? id,
    required this.name,
    this.subjectCode = '',
    this.instructorName = '',
    required this.weeklySchedule,
    int? updatedAt,
    this.goalPercent = 75,
    this.remindersEnabled = false,
    this.reminderMinutes = 15,
    this.carryPresent = 0,
    this.carryAbsent = 0,
    this.isHourWise = false,
    Map<int, int>? weeklyHours,
  }) : weeklyHours = weeklyHours ?? <int, int>{},
       id = id ?? _newId(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  DateTime _normalize(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    return DateTime(local.year, local.month, local.day);
  }

  void markAttendance(DateTime date, int index, AttendanceStatus? status) {
    final normalized = _normalize(date);
    final slots = getSlotsFor(date);
    final existing = attendance[normalized];
    final targetLength = math.max(
      math.max(slots.length, existing?.length ?? 0),
      index + 1,
    );
    if (targetLength <= 0) return;

    attendance.putIfAbsent(normalized, () => List.filled(targetLength, null));
    if (attendance[normalized]!.length < targetLength) {
      attendance[normalized]!.length = targetLength;
    }

    if (index >= 0 && index < attendance[normalized]!.length) {
      attendance[normalized]![index] = status;
      touch();
    }
  }

  List<AttendanceStatus?>? getAttendanceFor(DateTime date) =>
      attendance[_normalize(date)];

  List<LectureSlot> getSlotsFor(DateTime date) {
    final normalized = _normalize(date);
    final rescheduled = rescheduledLectures[normalized];
    if (rescheduled != null) return rescheduled;
    if (isHourWise) {
      final scheduled = hoursForWeekday(date.weekday);
      if (scheduled <= 0) return [];
      final endHour = (9 + scheduled).clamp(0, 23).toInt();
      return [
        LectureSlot(
          start: const TimeOfDay(hour: 9, minute: 0),
          end: TimeOfDay(hour: endHour, minute: 0),
        ),
      ];
    }
    return weeklySchedule[date.weekday] ?? [];
  }

  DateTime getOriginalDate(DateTime date, int index) {
    final normalized = _normalize(date);
    final originalList = _originalDates[normalized];
    if (originalList != null && index >= 0 && index < originalList.length) {
      return originalList[index];
    }
    return normalized;
  }

  void rescheduleLecture(
    DateTime oldDate,
    int index,
    DateTime newDate,
    LectureSlot newSlot,
  ) {
    final normalizedOld = _normalize(oldDate);
    final normalizedNew = _normalize(newDate);

    final original = getOriginalDate(oldDate, index);

    _originalDates.putIfAbsent(normalizedNew, () => []);
    _originalDates[normalizedNew]!.add(original);

    rescheduledLectures.putIfAbsent(normalizedNew, () => []);
    rescheduledLectures[normalizedNew]!.add(newSlot);

    markAttendance(normalizedOld, index, null);
    touch();
  }

  void markHoliday(DateTime date) {
    final normalized = _normalize(date);
    final slots = getSlotsFor(date);
    final existing = attendance[normalized];
    final targetLength = math.max(slots.length, existing?.length ?? 0);
    if (targetLength <= 0) return;

    attendance[normalized] = List.filled(
      targetLength,
      AttendanceStatus.cancelled,
    );
    touch();
  }

  int get attended =>
      carryPresent +
      _attendanceUnitsFor(AttendanceStatus.present);

  int get total =>
      carryPresent +
      carryAbsent +
      _attendanceUnitsForNonCancelled();

  double get attendancePercentage => total == 0 ? 0 : (attended / total) * 100;

  int bunkableCount({double threshold = 0.75}) {
    if (total == 0) return 0;
    final maxMisses = (attended / threshold) - total;
    return math.max(0, maxMisses.floor());
  }

  int get cancelled {
    int sum = 0;
    for (final entry in attendance.entries) {
      final date = entry.key;
      final list = entry.value;
      if (!isHourWise) {
        sum += list.where((e) => e == AttendanceStatus.cancelled).length;
        continue;
      }
      final hasCancelled = list.any((e) => e == AttendanceStatus.cancelled);
      if (hasCancelled) {
        sum += hoursForWeekday(date.weekday);
      }
    }
    return sum;
  }

  int get absent =>
      carryAbsent +
      _attendanceUnitsFor(AttendanceStatus.absent);

  int get present => attended;

  AttendanceStreak streak() {
    final entries = <_AttendanceEntry>[];
    final dates = attendance.keys.toList()..sort();
    for (final date in dates) {
      final list = attendance[date] ?? [];
      for (var i = 0; i < list.length; i++) {
        final status = list[i];
        if (status == AttendanceStatus.present ||
            status == AttendanceStatus.absent) {
          entries.add(_AttendanceEntry(date, i, status!));
        }
      }
    }
    if (entries.isEmpty) {
      return AttendanceStreak.none();
    }
    entries.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      return a.index.compareTo(b.index);
    });
    final last = entries.last;
    var count = 1;
    for (var i = entries.length - 2; i >= 0; i--) {
      if (entries[i].status == last.status) {
        count++;
      } else {
        break;
      }
    }
    return AttendanceStreak(last.status, count);
  }

  double weeklyAttendanceRate({int days = 7}) {
    final end = _normalize(DateTime.now());
    final start = end.subtract(Duration(days: days - 1));
    int presentCount = 0;
    int totalCount = 0;
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final list = attendance[_normalize(d)] ?? [];
      if (isHourWise) {
        final first = list.cast<AttendanceStatus?>().firstWhere(
              (s) => s != null,
              orElse: () => null,
            );
        if (first == null || first == AttendanceStatus.cancelled) continue;
        final hours = hoursForWeekday(d.weekday);
        totalCount += hours;
        if (first == AttendanceStatus.present) {
          presentCount += hours;
        }
        continue;
      }
      for (final status in list) {
        if (status == null || status == AttendanceStatus.cancelled) continue;
        totalCount++;
        if (status == AttendanceStatus.present) presentCount++;
      }
    }
    return totalCount == 0 ? 0 : (presentCount / totalCount) * 100;
  }

  AttendanceForecast forecast(int nextCount) {
    final baseAttended = attended;
    final baseTotal = total;
    final denom = baseTotal + nextCount;
    final attendPct = denom == 0
        ? 0.0
        : ((baseAttended + nextCount) / denom * 100).toDouble();
    final missPct =
        denom == 0 ? 0.0 : ((baseAttended) / denom * 100).toDouble();
    return AttendanceForecast(attendPct, missPct);
  }

  void markHolidayRange(DateTime start, DateTime end) {
    var current = _normalize(start);
    final last = _normalize(end);
    while (!current.isAfter(last)) {
      markHoliday(current);
      current = current.add(const Duration(days: 1));
    }
    touch();
  }

  void touch() {
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  int hoursForWeekday(int weekday) {
    final value = weeklyHours[weekday] ?? 0;
    if (value < 0) return 0;
    return value > 24 ? 24 : value;
  }

  String get unitLabel => isHourWise ? 'hrs' : 'classes';

  int _attendanceUnitsFor(AttendanceStatus target) {
    int sum = 0;
    for (final entry in attendance.entries) {
      final date = entry.key;
      final list = entry.value;
      if (!isHourWise) {
        sum += list.where((s) => s == target).length;
        continue;
      }
      final first = list.cast<AttendanceStatus?>().firstWhere(
            (s) => s != null,
            orElse: () => null,
          );
      if (first == target) {
        sum += hoursForWeekday(date.weekday);
      }
    }
    return sum;
  }

  int _attendanceUnitsForNonCancelled() {
    int sum = 0;
    for (final entry in attendance.entries) {
      final date = entry.key;
      final list = entry.value;
      if (!isHourWise) {
        sum += list
            .where((s) => s != null && s != AttendanceStatus.cancelled)
            .length;
        continue;
      }
      final first = list.cast<AttendanceStatus?>().firstWhere(
            (s) => s != null,
            orElse: () => null,
          );
      if (first != null && first != AttendanceStatus.cancelled) {
        sum += hoursForWeekday(date.weekday);
      }
    }
    return sum;
  }

  // -------------------------------
  // HIVE SERIALIZATION
  // -------------------------------

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subjectCode': subjectCode,
      'instructorName': instructorName,
      'id': id,
      'updatedAt': updatedAt,
      'goalPercent': goalPercent,
      'remindersEnabled': remindersEnabled,
      'reminderMinutes': reminderMinutes,
      'carryPresent': carryPresent,
      'carryAbsent': carryAbsent,
      'isHourWise': isHourWise,
      'weeklyHours': weeklyHours.map(
        (key, value) => MapEntry(_weekdayName(key), value),
      ),
      'weeklySchedule': weeklySchedule.map(
        (key, value) =>
            MapEntry(key.toString(), value.map((e) => e.toMap()).toList()),
      ),
      'attendance': attendance.map(
        (key, value) => MapEntry(
          key.toIso8601String(),
          value.map((e) => e?.index).toList(),
        ),
      ),
      'rescheduledLectures': rescheduledLectures.map(
        (key, value) => MapEntry(
          key.toIso8601String(),
          value.map((e) => e.toMap()).toList(),
        ),
      ),
      'originalDates': _originalDates.map(
        (key, value) => MapEntry(
          key.toIso8601String(),
          value.map((e) => e.toIso8601String()).toList(),
        ),
      ),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    final subject = Subject(
      id: (map['id'] ?? _newId()).toString(),
      name: map['name'],
      subjectCode: (map['subjectCode'] ?? '').toString(),
      instructorName: (map['instructorName'] ?? '').toString(),
      updatedAt: map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      goalPercent: (map['goalPercent'] ?? 75).toDouble(),
      remindersEnabled: map['remindersEnabled'] ?? false,
      reminderMinutes: map['reminderMinutes'] ?? 15,
      carryPresent: (map['carryPresent'] ?? 0) is num
          ? (map['carryPresent'] ?? 0).toInt()
          : 0,
      carryAbsent: (map['carryAbsent'] ?? 0) is num
          ? (map['carryAbsent'] ?? 0).toInt()
          : 0,
      isHourWise: map['isHourWise'] == true,
      weeklyHours: _parseWeeklyHours(map['weeklyHours']),
      weeklySchedule: ((map['weeklySchedule'] ?? {}) as Map).map(
        (key, value) => MapEntry(
          int.parse(key),
          (value as List)
              .map((e) => LectureSlot.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
        ),
      ),
    );

    // Attendance
    if (map['attendance'] != null) {
      subject.attendance = (map['attendance'] as Map).map(
        (key, value) => MapEntry(
          DateTime.parse(key),
          (value as List)
              .map((e) => e == null ? null : AttendanceStatus.values[e])
              .toList(),
        ),
      );
    }

    // Rescheduled
    if (map['rescheduledLectures'] != null) {
      subject.rescheduledLectures = (map['rescheduledLectures'] as Map).map(
        (key, value) => MapEntry(
          DateTime.parse(key),
          (value as List)
              .map((e) => LectureSlot.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
        ),
      );
    }

    // Original Dates
    if (map['originalDates'] != null) {
      subject._originalDates = (map['originalDates'] as Map).map(
        (key, value) => MapEntry(
          DateTime.parse(key),
          (value as List).map((e) => DateTime.parse(e)).toList(),
        ),
      );
    }

    return subject;
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

Map<int, int> _parseWeeklyHours(dynamic raw) {
  if (raw is! Map) return <int, int>{};
  final result = <int, int>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString();
    final day = _weekdayFromKey(key);
    if (day == null) continue;
    final value = entry.value;
    final hours = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    if (hours < 0) {
      result[day] = 0;
    } else if (hours > 24) {
      result[day] = 24;
    } else {
      result[day] = hours;
    }
  }
  return result;
}

String _weekdayName(int day) {
  const names = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };
  return names[day] ?? day.toString();
}

int? _weekdayFromKey(String key) {
  final numeric = int.tryParse(key);
  if (numeric != null && numeric >= 1 && numeric <= 7) return numeric;
  switch (key.toLowerCase()) {
    case 'monday':
      return 1;
    case 'tuesday':
      return 2;
    case 'wednesday':
      return 3;
    case 'thursday':
      return 4;
    case 'friday':
      return 5;
    case 'saturday':
      return 6;
    case 'sunday':
      return 7;
    default:
      return null;
  }
}

class _AttendanceEntry {
  final DateTime date;
  final int index;
  final AttendanceStatus status;
  _AttendanceEntry(this.date, this.index, this.status);
}

class AttendanceStreak {
  final AttendanceStatus? status;
  final int count;
  const AttendanceStreak(this.status, this.count);
  factory AttendanceStreak.none() => const AttendanceStreak(null, 0);
}

class AttendanceForecast {
  final double attendNextPct;
  final double missNextPct;
  const AttendanceForecast(this.attendNextPct, this.missNextPct);
}
