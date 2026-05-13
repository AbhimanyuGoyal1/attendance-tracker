import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import '../models/subject.dart';
import '../services/firestore_service.dart';

class HomeController extends GetxController {
  final Box _box = Hive.box('timetableBox');
  final FirestoreService _firestoreService = FirestoreService();

  final RxList<Subject> subjects = <Subject>[].obs;
  final RxString syncState = 'Synced'.obs;

  late AppSettings _settings;
  bool _syncInProgress = false;
  bool _syncQueued = false;
  bool _cloudPermissionDenied = false;

  String get subjectsKey =>
      'subjects_${_settings.currentSemester.replaceAll(' ', '_')}';
  String get _pendingDeletesKey =>
      'pending_deletes_${_settings.currentSemester.replaceAll(' ', '_')}';

  String _subjectsKeyFor(String semester) =>
      'subjects_${semester.replaceAll(' ', '_')}';
  String _pendingDeletesKeyFor(String semester) =>
      'pending_deletes_${semester.replaceAll(' ', '_')}';

  void initialize(AppSettings settings) {
    _settings = settings;
    syncState.value = _settings.autoCloudSync ? 'Synced' : 'Local only';
    loadSubjects();
    if (_settings.autoCloudSync) {
      loadFromCloud();
    }
  }

  void setSettings(AppSettings settings) {
    final prevSemester = _settings.currentSemester;
    final prevAutoCloud = _settings.autoCloudSync;

    _settings = settings;

    final semesterChanged = prevSemester != _settings.currentSemester;
    final autoCloudChanged = prevAutoCloud != _settings.autoCloudSync;

    if (!_settings.autoCloudSync) {
      syncState.value = 'Local only';
    } else if (syncState.value == 'Local only') {
      syncState.value = 'Synced';
    }

    if (semesterChanged) {
      loadSubjects();
    }

    if (_settings.autoCloudSync && (semesterChanged || autoCloudChanged)) {
      loadFromCloud();
    }
  }

  void loadSubjects() {
    final data = _box.get(subjectsKey, defaultValue: []);
    subjects.assignAll(
      (data as List)
          .map((e) => Subject.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  void saveSubjects() {
    final data = subjects.map((s) => s.toMap()).toList();
    _box.put(subjectsKey, data);
    if (_settings.autoCloudSync) {
      queueCloudSync();
    }
  }

  void queueCloudSync() {
    if (_cloudPermissionDenied) return;
    if (_syncInProgress) {
      _syncQueued = true;
      return;
    }
    saveToCloud();
  }

  Future<void> saveToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _syncInProgress = true;
    syncState.value = 'Syncing...';
    try {
      await _flushPendingDeletes(user.uid, _settings.currentSemester);
      final merged = await _firestoreService.syncSubjects(
        user.uid,
        _settings.currentSemester,
        subjects.toList(),
      );
      subjects.assignAll(merged);
      syncState.value = 'Synced';
      final data = subjects.map((s) => s.toMap()).toList();
      _box.put(subjectsKey, data);
    } catch (e) {
      final isPermissionDenied = e.toString().contains('PERMISSION_DENIED');
      syncState.value =
          isPermissionDenied ? 'Cloud permission denied' : 'Sync failed';
      if (isPermissionDenied) {
        _cloudPermissionDenied = true;
      } else {
        Future.delayed(const Duration(seconds: 4), () {
          if (_settings.autoCloudSync) queueCloudSync();
        });
      }
    } finally {
      _syncInProgress = false;
      if (_syncQueued) {
        _syncQueued = false;
        queueCloudSync();
      }
    }
  }

  Future<void> loadFromCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _flushPendingDeletes(user.uid, _settings.currentSemester);
      final remote = await _firestoreService.syncSubjects(
        user.uid,
        _settings.currentSemester,
        subjects.toList(),
      );
      subjects.assignAll(remote);
      syncState.value = 'Synced';
      final data = subjects.map((s) => s.toMap()).toList();
      _box.put(subjectsKey, data);
    } catch (e) {
      final isPermissionDenied = e.toString().contains('PERMISSION_DENIED');
      syncState.value =
          isPermissionDenied ? 'Cloud permission denied' : 'Sync failed';
      if (isPermissionDenied) _cloudPermissionDenied = true;
    }
  }

  Future<void> deleteRemoteSubject(String subjectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestoreService.deleteSubject(
      user.uid,
      _settings.currentSemester,
      subjectId,
    );
  }

  Future<void> enqueuePendingDelete(String subjectId) async {
    final pending = _readPendingDeletesFor(_settings.currentSemester);
    if (!pending.contains(subjectId)) {
      pending.add(subjectId);
      await _box.put(_pendingDeletesKey, pending);
    }
    syncState.value = 'Pending delete sync';
  }

  List<String> _readPendingDeletesFor(String semester) {
    final key = _pendingDeletesKeyFor(semester);
    final raw = _box.get(key, defaultValue: const []);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  Future<void> _flushPendingDeletes(String uid, String semester) async {
    final key = _pendingDeletesKeyFor(semester);
    final pending = _readPendingDeletesFor(semester);
    if (pending.isEmpty) return;
    final failed = <String>[];
    for (final subjectId in pending) {
      try {
        await _firestoreService.deleteSubject(uid, semester, subjectId);
      } catch (_) {
        failed.add(subjectId);
      }
    }
    await _box.put(key, failed);
  }

  void addSubject(Subject subject) {
    subject.goalPercent = _settings.defaultGoalPercent;
    subject.remindersEnabled = _settings.defaultSubjectReminderEnabled;
    subject.reminderMinutes = _settings.defaultSubjectReminderMinutes;
    subject.touch();
    subjects.add(subject);
    saveSubjects();
  }

  Subject removeSubjectAt(int index) {
    final removed = subjects.removeAt(index);
    saveSubjects();
    return removed;
  }

  void markAttendance(
    Subject subject,
    DateTime date,
    int slotIndex,
    AttendanceStatus? status,
  ) {
    subject.markAttendance(date, slotIndex, status);
    subjects.refresh();
    saveSubjects();
  }

  void rescheduleAndCancel(
    Subject subject,
    DateTime oldDate,
    int slotIndex,
    DateTime newDate,
    LectureSlot newSlot,
  ) {
    subject.rescheduleLecture(oldDate, slotIndex, newDate, newSlot);
    subject.markAttendance(oldDate, slotIndex, AttendanceStatus.cancelled);
    subjects.refresh();
    saveSubjects();
  }

  void cancelLecture(Subject subject, DateTime date, int slotIndex) {
    subject.markAttendance(date, slotIndex, AttendanceStatus.cancelled);
    subjects.refresh();
    saveSubjects();
  }

  void updateReminder(
    Subject subject, {
    required bool enabled,
    required int minutes,
  }) {
    subject.remindersEnabled = enabled;
    subject.reminderMinutes = minutes;
    subject.touch();
    subjects.refresh();
    saveSubjects();
  }

  void updateGoal(Subject subject, double goalPercent) {
    subject.goalPercent = goalPercent;
    subject.touch();
    subjects.refresh();
    saveSubjects();
  }

  void updateWeeklySchedule(Subject subject, Map<int, List<LectureSlot>> slots) {
    subject.weeklySchedule = slots;
    subject.touch();
    subjects.refresh();
    saveSubjects();
  }

  void updateSubjectDetails(
    Subject subject, {
    required String name,
    required String subjectCode,
    required String instructorName,
    bool? isHourWise,
    Map<int, int>? weeklyHours,
  }) {
    subject.name = name.trim();
    subject.subjectCode = subjectCode.trim();
    subject.instructorName = instructorName.trim();
    if (isHourWise != null) {
      subject.isHourWise = isHourWise;
    }
    if (weeklyHours != null) {
      subject.weeklyHours = weeklyHours;
    }
    subject.touch();
    subjects.refresh();
    saveSubjects();
  }

  Future<bool> renameSemester(String oldName, String newName) async {
    final oldKey = _subjectsKeyFor(oldName);
    final newKey = _subjectsKeyFor(newName);
    final oldPendingKey = _pendingDeletesKeyFor(oldName);
    final newPendingKey = _pendingDeletesKeyFor(newName);
    if (oldKey == newKey) return true;
    if (_box.containsKey(newKey)) return false;

    final oldData = _box.get(oldKey, defaultValue: []);
    await _box.put(newKey, oldData);
    await _box.delete(oldKey);
    final oldPending = _box.get(oldPendingKey, defaultValue: const []);
    if (!_box.containsKey(newPendingKey)) {
      await _box.put(newPendingKey, oldPending);
    }
    await _box.delete(oldPendingKey);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _settings.autoCloudSync) {
      try {
        final oldSubjects = await _firestoreService.loadSubjects(user.uid, oldName);
        await _firestoreService.syncSubjects(user.uid, newName, oldSubjects);
        await _firestoreService.deleteSemesterData(user.uid, oldName);
      } catch (_) {
        // Keep local rename successful even if cloud move fails.
      }
    }
    return true;
  }
}
