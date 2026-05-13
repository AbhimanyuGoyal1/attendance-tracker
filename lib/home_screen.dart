import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/home_controller.dart';
import 'models/app_settings.dart';
import 'models/subject.dart';
import 'services/android_power_settings_service.dart';
import 'services/notification_service.dart';
import 'widgets/animated_fade_slide.dart';
import 'screens/add_subject_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/edit_subject_details_screen.dart';
import 'screens/edit_subject_schedule_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _homeController;
  final NotificationService _notificationService = NotificationService();
  final AndroidPowerSettingsService _powerSettingsService =
      AndroidPowerSettingsService();

  late AppSettings _settings;
  bool _guideRunning = false;
  int _guideStep = 0;
  String? _expandedSubjectId;
  Timer? _undoSnackTimer;

  List<Subject> get subjects => _homeController.subjects;
  String get _syncState => _homeController.syncState.value;
  String get _subjectsKey => _homeController.subjectsKey;

  @override
  void initState() {
    super.initState();
    _homeController = Get.put(HomeController(), tag: 'home_controller');
    _settings = widget.settings;
    _homeController.initialize(_settings);
    Future.microtask(_syncReminders);
    Future.microtask(_maybeStartInteractiveGuide);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _homeController.setSettings(_settings);
      _maybeStartInteractiveGuide();
    }
  }

  @override
  void dispose() {
    _undoSnackTimer?.cancel();
    Get.delete<HomeController>(tag: 'home_controller', force: true);
    super.dispose();
  }

  void _maybeStartInteractiveGuide() {
    if (_settings.interactiveGuideEnabled && !_guideRunning) {
      setState(() {
        _guideRunning = true;
        final savedStep = _settings.interactiveGuideStep;
        _guideStep = subjects.isEmpty ? 0 : savedStep.clamp(0, 5);
      });
    }
  }

  void _advanceGuide() {
    if (!_guideRunning) return;
    setState(() {
      _guideStep += 1;
      if (_guideStep > 5) {
        _finishGuide();
      } else {
        final updated = AppSettings.fromMap(_settings.toMap());
        updated.interactiveGuideStep = _guideStep;
        _settings = updated;
        widget.onSettingsChanged(updated);
      }
    });
  }

  void _finishGuide() {
    _guideRunning = false;
    _guideStep = 0;
    if (_settings.interactiveGuideEnabled) {
      final updated = AppSettings.fromMap(_settings.toMap());
      updated.interactiveGuideEnabled = false;
      updated.interactiveGuideStep = 0;
      _settings = updated;
      widget.onSettingsChanged(updated);
      _homeController.setSettings(updated);
    }
  }

  Future<void> _openAddSubject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSubjectScreen()),
    );
    if (result is Subject) {
      _homeController.addSubject(result);
      if (result.remindersEnabled) {
        await _notificationService.scheduleSubjectReminders(
          result,
          semesterKey: _subjectsKey,
        );
      }
      if (_guideRunning && _guideStep == 0) {
        _advanceGuide();
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: _settings,
          onRenameSemester: (oldName, newName) =>
              _homeController.renameSemester(oldName, newName),
          onChanged: (updated) {
            if (!mounted) return;
            _settings = updated;
            _homeController.setSettings(updated);
            widget.onSettingsChanged(updated);
          },
        ),
      ),
    );
    _homeController.saveSubjects();
    if (_guideRunning && _guideStep == 5) {
      _advanceGuide();
    }
  }

  Future<void> _openTimetable() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimetableScreen(
          subjects: subjects,
          onChanged: _homeController.saveSubjects,
        ),
      ),
    );
    _homeController.loadSubjects();
    if (_guideRunning && _guideStep == 4) {
      _advanceGuide();
    }
  }

  Future<void> _openAnalytics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnalyticsScreen(subjects: subjects)),
    );
  }

  Future<void> _deleteSubject(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: const Text(
          'This will remove all attendance history for this subject.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final target = subjects[index];
    try {
      await _homeController.deleteRemoteSubject(target.id);
      _homeController.removeSubjectAt(index);
      if (_expandedSubjectId == target.id) {
        setState(() => _expandedSubjectId = null);
      }
    } catch (_) {
      await _homeController.enqueuePendingDelete(target.id);
      _homeController.removeSubjectAt(index);
      if (_expandedSubjectId == target.id) {
        setState(() => _expandedSubjectId = null);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleted locally. Cloud delete will retry automatically.'),
        ),
      );
    }
  }

  void _mark(
    Subject subject,
    DateTime date,
    int slotIndex,
    AttendanceStatus status,
  ) {
    final previous = subject.getAttendanceFor(date)?[slotIndex];
    _homeController.markAttendance(subject, date, slotIndex, status);
    if (_guideRunning && _guideStep == 3) {
      _advanceGuide();
    }
    _showUndoMark(subject, date, slotIndex, previous);
  }

  void _showUndoMark(
    Subject subject,
    DateTime date,
    int slotIndex,
    AttendanceStatus? previous,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    _undoSnackTimer?.cancel();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: const Text('Attendance updated'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _undoSnackTimer?.cancel();
            messenger.hideCurrentSnackBar();
            _homeController.markAttendance(subject, date, slotIndex, previous);
          },
        ),
      ),
    );
    _undoSnackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
    });
  }

  Future<void> _showForecast(Subject subject) async {
    var nextCount = 3;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final forecast = subject.forecast(nextCount);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Forecast',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(_subjectLabel(subject)),
                  const SizedBox(height: 16),
                  Text(
                    subject.isHourWise
                        ? 'Next $nextCount hours'
                        : 'Next $nextCount classes',
                  ),
                  Slider(
                    value: nextCount.toDouble(),
                    min: 1,
                    max: subject.isHourWise ? 20 : 10,
                    divisions: subject.isHourWise ? 19 : 9,
                    label: '$nextCount',
                    onChanged: (v) => setSheetState(() {
                      nextCount = v.round();
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ForecastCard(
                          title: 'If you attend',
                          value: '${forecast.attendNextPct.toStringAsFixed(1)}%',
                          color: const Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ForecastCard(
                          title: 'If you miss',
                          value: '${forecast.missNextPct.toStringAsFixed(1)}%',
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (_guideRunning && _guideStep == 2) {
      _advanceGuide();
    }
  }
  Future<void> _showReminderSheet(Subject subject) async {
    final minutesOptions = [5, 10, 15, 30, 60];
    var enabled = subject.remindersEnabled;
    var selected = subject.reminderMinutes;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lecture Reminders',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(_subjectLabel(subject)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable reminders'),
                    value: enabled,
                    onChanged: (v) => setSheetState(() => enabled = v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: minutesOptions
                        .map(
                          (m) => ChoiceChip(
                            label: Text('$m min'),
                            selected: selected == m,
                            onSelected: enabled
                                ? (_) => setSheetState(() => selected = m)
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (enabled) {
      final granted = await _notificationService.ensurePermissions();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is off. Enable it from app settings.',
            ),
          ),
        );
      } else {
        if (!mounted) return;
        await _powerSettingsService.showSetupDialog(context);
      }
    }

    _homeController.updateReminder(subject, enabled: enabled, minutes: selected);
    await _notificationService.cancelSubjectReminders(subject);
    if (subject.remindersEnabled) {
      await _notificationService.scheduleSubjectReminders(
        subject,
        semesterKey: _subjectsKey,
      );
    }
  }

  Future<void> _showGoalSheet(Subject subject) async {
    var selected = subject.goalPercent;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set attendance goal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    min: 60,
                    max: 95,
                    divisions: 7,
                    value: selected,
                    label: '${selected.toInt()}%',
                    onChanged: (v) => setSheetState(() => selected = v),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved == true) {
      _homeController.updateGoal(subject, selected);
    }
  }

  Future<void> _editSubjectSlots(Subject subject) async {
    await _notificationService.cancelSubjectReminders(subject);
    if (!mounted) return;
    final updated = await Navigator.push<Map<int, List<LectureSlot>>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditSubjectScheduleScreen(subject: subject),
      ),
    );
    if (updated == null) {
      if (subject.remindersEnabled) {
        await _notificationService.scheduleSubjectReminders(
          subject,
          semesterKey: _subjectsKey,
        );
      }
      return;
    }

    _homeController.updateWeeklySchedule(subject, updated);
    if (subject.remindersEnabled) {
      await _notificationService.scheduleSubjectReminders(
        subject,
        semesterKey: _subjectsKey,
      );
    }
  }

  Future<void> _editSubjectDetails(Subject subject) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditSubjectDetailsScreen(subject: subject),
      ),
    );
    if (!mounted || result == null) return;
    _homeController.updateSubjectDetails(
      subject,
      name: result['name'] ?? subject.name,
      subjectCode: result['subjectCode'] ?? subject.subjectCode,
      instructorName: result['instructorName'] ?? subject.instructorName,
      isHourWise: result['isHourWise'] is bool
          ? result['isHourWise'] as bool
          : null,
      weeklyHours: _parseWeeklyHours(result['weeklyHours']),
    );
  }

  Future<void> _syncReminders() async {
    for (final subject in subjects) {
      if (subject.remindersEnabled) {
        await _notificationService.cancelSubjectReminders(subject);
        await _notificationService.scheduleSubjectReminders(
          subject,
          semesterKey: _subjectsKey,
        );
      }
    }
  }

  Future<void> _startDailyMarkFlow(
    List<_LectureEntry> todaysLectures,
    DateTime date,
  ) async {
    for (final entry in todaysLectures) {
      final status = entry.subject.getAttendanceFor(date)?[entry.slotIndex];
      if (status != null) continue;
      final action = await showModalBottomSheet<AttendanceStatus>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_subjectLabel(entry.subject)} (${entry.slot.format(context)})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, AttendanceStatus.present),
                          child: const Text('Present'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () =>
                              Navigator.pop(context, AttendanceStatus.absent),
                          child: const Text('Absent'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (action != null) {
        _mark(entry.subject, date, entry.slotIndex, action);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final today = DateTime.now();
      final bottomInset = MediaQuery.of(context).viewPadding.bottom;

      final lectures = <_LectureEntry>[];
      for (final subject in subjects) {
        final slots = subject.getSlotsFor(today);
        for (int i = 0; i < slots.length; i++) {
          final originalDate = subject.getOriginalDate(today, i);
          lectures.add(
            _LectureEntry(
              subject: subject,
              slot: slots[i],
              slotIndex: i,
              originalWeekday: originalDate.weekday,
            ),
          );
        }
      }
      lectures.sort(
        (a, b) => _slotStartMinutes(a.slot).compareTo(_slotStartMinutes(b.slot)),
      );

      final totalAttended = subjects.fold<int>(0, (s, e) => s + e.attended);
      final totalUnits = subjects.fold<int>(0, (s, e) => s + e.total);
      final overallPercent =
          totalUnits == 0 ? 0.0 : (totalAttended / totalUnits) * 100;

      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Attendance Tracker'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: _openSettings,
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Today'),
                Tab(text: 'Subjects'),
              ],
            ),
          ),
          body: Stack(
            children: [
              TabBarView(
                children: [
                  _buildTodayTab(
                    today: today,
                    lectures: lectures,
                    overallPercent: overallPercent,
                    totalAttended: totalAttended,
                    totalUnits: totalUnits,
                  ),
                  _buildSubjectsTab(),
                ],
              ),
              if (_guideRunning)
                _GuideCoach(
                  step: _guideStep,
                  canProceed: _canProceedGuideStep(lectures),
                  onSkip: () => setState(_finishGuide),
                  onAction: () => _performGuideAction(lectures),
                  onNext: _advanceGuide,
                ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: bottomInset + 8),
            child: FloatingActionButton(
              tooltip: 'Add Subject',
              onPressed: _openAddSubject,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTodayTab({
    required DateTime today,
    required List<_LectureEntry> lectures,
    required double overallPercent,
    required int totalAttended,
    required int totalUnits,
  }) {
    final pending = lectures
        .where((e) => e.subject.getAttendanceFor(today)?[e.slotIndex] == null)
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
      itemCount: 2 + (lectures.isEmpty ? 1 : lectures.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PremiumSummaryCard(
            date: today,
            overallPercent: overallPercent,
            totalAttended: totalAttended,
            totalUnits: totalUnits,
            syncState: _syncState,
          );
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: _QuickActionsRow(
              actions: [
                _QuickActionItem(
                  icon: Icons.play_circle_outline,
                  tooltip: 'Mark pending lectures',
                  onTap: pending.isEmpty
                      ? null
                      : () => _startDailyMarkFlow(lectures, today),
                ),
                _QuickActionItem(
                  icon: Icons.calendar_today,
                  tooltip: 'Timetable',
                  onTap: _openTimetable,
                ),
                _QuickActionItem(
                  icon: Icons.analytics_outlined,
                  tooltip: 'Analytics',
                  onTap: _openAnalytics,
                ),
                _QuickActionItem(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onTap: _openSettings,
                ),
              ],
            ),
          );
        }

        if (lectures.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No lectures scheduled for today.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final entry = lectures[index - 2];
        final status = entry.subject.getAttendanceFor(today)?[entry.slotIndex];
        final statusData = _getStatusData(
          status: status,
          slotDate: today,
          originalWeekday: entry.originalWeekday,
        );

        return AnimatedFadeSlide(
          delay: Duration(milliseconds: 40 * (index - 1)),
          child: _LectureCard(
            idKey:
                '${entry.subject.id}_${today.toIso8601String()}_${entry.slotIndex}',
            title: _subjectLabel(entry.subject),
            time: entry.slot.format(context),
            statusText: statusData.text,
            statusColor: statusData.color,
            activeStatus: status,
            onPresent: () => _mark(
              entry.subject,
              today,
              entry.slotIndex,
              AttendanceStatus.present,
            ),
            onAbsent: () => _mark(
              entry.subject,
              today,
              entry.slotIndex,
              AttendanceStatus.absent,
            ),
            onCancel: () {
              _homeController.cancelLecture(entry.subject, today, entry.slotIndex);
              _showUndoMark(entry.subject, today, entry.slotIndex, status);
            },
            swipeEnabled: _settings.enableSwipeActions,
            onSwipePresent: () => _mark(
              entry.subject,
              today,
              entry.slotIndex,
              AttendanceStatus.present,
            ),
            onSwipeAbsent: () => _mark(
              entry.subject,
              today,
              entry.slotIndex,
              AttendanceStatus.absent,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectsTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
      itemCount: 2 + (subjects.isEmpty ? 1 : subjects.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SectionBanner(
            title: 'All Subjects',
            subtitle: subjects.isEmpty
                ? 'Add your first subject to begin tracking.'
                : '${subjects.length} subjects in this semester.',
          );
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: _QuickActionsRow(
              actions: [
                _QuickActionItem(
                  icon: Icons.add,
                  tooltip: 'Add subject',
                  onTap: _openAddSubject,
                ),
                _QuickActionItem(
                  icon: Icons.calendar_view_week_outlined,
                  tooltip: 'Weekly timetable',
                  onTap: _openTimetable,
                ),
                _QuickActionItem(
                  icon: Icons.analytics_outlined,
                  tooltip: 'Analytics',
                  onTap: _openAnalytics,
                ),
                _QuickActionItem(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onTap: _openSettings,
                ),
              ],
            ),
          );
        }
        if (subjects.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Tap + to add a subject, then expand it to access forecast, reminders and goals.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final subjectIndex = index - 2;
        final subject = subjects[subjectIndex];
        final expanded = subject.id == _expandedSubjectId;

        return AnimatedFadeSlide(
          delay: Duration(milliseconds: 35 * subjectIndex),
          child: _SubjectAccordionCard(
            subject: subject,
            expanded: expanded,
            onToggle: () {
              setState(() {
                _expandedSubjectId = expanded ? null : subject.id;
              });
              if (_guideRunning && _guideStep == 1 && !expanded) {
                _advanceGuide();
              }
            },
            onForecast: () => _showForecast(subject),
            onGoal: () => _showGoalSheet(subject),
            onReminder: () => _showReminderSheet(subject),
            onEditDetails: () => _editSubjectDetails(subject),
            onEditSlots: () => _editSubjectSlots(subject),
            onDelete: () => _deleteSubject(subjectIndex),
          ),
        );
      },
    );
  }

  bool _canProceedGuideStep(List<_LectureEntry> lectures) {
    switch (_guideStep) {
      case 0:
        return subjects.isNotEmpty;
      case 1:
        return _expandedSubjectId != null;
      case 2:
        return false;
      case 3:
        return lectures.isEmpty;
      case 4:
      case 5:
        return false;
      default:
        return true;
    }
  }

  Future<void> _performGuideAction(List<_LectureEntry> lectures) async {
    switch (_guideStep) {
      case 0:
        await _openAddSubject();
        break;
      case 1:
        if (_expandedSubjectId == null && subjects.isNotEmpty) {
          setState(() => _expandedSubjectId = subjects.first.id);
        }
        break;
      case 2:
        final subject =
            subjects.firstWhereOrNull((s) => s.id == _expandedSubjectId) ??
                subjects.firstOrNull;
        if (subject != null) {
          await _showForecast(subject);
        }
        break;
      case 3:
        if (lectures.isNotEmpty) {
          await _startDailyMarkFlow(lectures, DateTime.now());
        }
        break;
      case 4:
        await _openTimetable();
        break;
      case 5:
        await _openSettings();
        break;
      default:
        _advanceGuide();
    }
  }

  _StatusData _getStatusData({
    required AttendanceStatus? status,
    required DateTime slotDate,
    required int originalWeekday,
  }) {
    final isRescheduled = slotDate.weekday != originalWeekday;
    switch (status) {
      case AttendanceStatus.present:
        return _StatusData(
          isRescheduled ? 'Present (Rescheduled)' : 'Present',
          Colors.green,
        );
      case AttendanceStatus.absent:
        return _StatusData(
          isRescheduled ? 'Absent (Rescheduled)' : 'Absent',
          Colors.red,
        );
      case AttendanceStatus.cancelled:
        return _StatusData(
          isRescheduled ? 'Cancelled (Rescheduled)' : 'Cancelled',
          Colors.orange,
        );
      default:
        return _StatusData(
          isRescheduled ? 'Not marked (Rescheduled)' : 'Not marked',
          Colors.grey,
        );
    }
  }

  int _slotStartMinutes(LectureSlot slot) =>
      slot.start.hour * 60 + slot.start.minute;

  String _subjectLabel(Subject subject) {
    final code = subject.subjectCode.trim();
    if (code.isEmpty) return subject.name;
    return '$code - ${subject.name}';
  }

  Map<int, int>? _parseWeeklyHours(dynamic value) {
    if (value is! Map) return null;
    final out = <int, int>{};
    for (final entry in value.entries) {
      final day = entry.key is int
          ? entry.key as int
          : int.tryParse(entry.key.toString());
      if (day == null) continue;
      final hours = entry.value is num
          ? (entry.value as num).toInt()
          : int.tryParse(entry.value.toString()) ?? 0;
      out[day] = hours;
    }
    return out;
  }
}

class _PremiumSummaryCard extends StatelessWidget {
  final DateTime date;
  final double overallPercent;
  final int totalAttended;
  final int totalUnits;
  final String syncState;

  const _PremiumSummaryCard({
    required this.date,
    required this.overallPercent,
    required this.totalAttended,
    required this.totalUnits,
    required this.syncState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  syncState,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${overallPercent.toStringAsFixed(1)}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$totalAttended / $totalUnits',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              Text(
                'tracked units',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _QuickActionItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
}

class _QuickActionsRow extends StatelessWidget {
  final List<_QuickActionItem> actions;

  const _QuickActionsRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions
          .map(
            (action) => Expanded(
              child: Tooltip(
                message: action.tooltip,
                child: IconButton.filledTonal(
                  onPressed: action.onTap,
                  icon: Icon(action.icon),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SubjectAccordionCard extends StatelessWidget {
  final Subject subject;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onForecast;
  final VoidCallback onGoal;
  final VoidCallback onReminder;
  final VoidCallback onEditDetails;
  final VoidCallback onEditSlots;
  final VoidCallback onDelete;

  const _SubjectAccordionCard({
    required this.subject,
    required this.expanded,
    required this.onToggle,
    required this.onForecast,
    required this.onGoal,
    required this.onReminder,
    required this.onEditDetails,
    required this.onEditSlots,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percentage = subject.attendancePercentage;
    final low = percentage < subject.goalPercent;
    final bunkable = subject.bunkableCount(threshold: subject.goalPercent / 100);
    final streak = subject.streak();
    final weekly = subject.weeklyAttendanceRate();

    final headline = subject.total == 0
        ? 'No attendance data yet'
        : low
            ? 'Below target ${subject.goalPercent.toStringAsFixed(0)}%'
            : 'Safe to miss $bunkable more ${subject.isHourWise ? 'hours' : 'classes'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.subjectCode.trim().isEmpty
                              ? subject.name
                              : '${subject.subjectCode} - ${subject.name}',
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subject.isHourWise)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Hour-wise',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          '$headline  •  ${subject.attended}/${subject.total} ${subject.unitLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        if (subject.instructorName.trim().isNotEmpty)
                          Text(
                            subject.instructorName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: low
                          ? Colors.red.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: low ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: 'Goal ${subject.goalPercent.toStringAsFixed(0)}%',
                      ),
                      _InfoChip(
                        label: streak.count == 0
                            ? 'Streak --'
                            : 'Streak ${streak.count} ${streak.status == AttendanceStatus.present ? 'P' : 'A'}',
                      ),
                      _InfoChip(label: '7d ${weekly.toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _CircleAction(
                        icon: Icons.auto_graph,
                        tooltip: 'Forecast',
                        onTap: onForecast,
                      ),
                      _CircleAction(
                        icon: Icons.flag_outlined,
                        tooltip: 'Goal',
                        onTap: onGoal,
                      ),
                      _CircleAction(
                        icon: subject.remindersEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        tooltip: 'Reminders',
                        onTap: onReminder,
                      ),
                      _CircleAction(
                        icon: Icons.edit_note_outlined,
                        tooltip: 'Edit details',
                        onTap: onEditDetails,
                      ),
                      if (!subject.isHourWise)
                        _CircleAction(
                          icon: Icons.edit_calendar_outlined,
                          tooltip: 'Edit slots',
                          onTap: onEditSlots,
                        ),
                      _CircleAction(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete subject',
                        onTap: onDelete,
                        danger: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: IconButton.filledTonal(
          onPressed: onTap,
          style: IconButton.styleFrom(
            foregroundColor: danger ? Colors.red : null,
          ),
          icon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _GuideCoach extends StatelessWidget {
  final int step;
  final bool canProceed;
  final VoidCallback onSkip;
  final VoidCallback onAction;
  final VoidCallback onNext;

  const _GuideCoach({
    required this.step,
    required this.canProceed,
    required this.onSkip,
    required this.onAction,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final data = _guideData(step);
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    // Keep guide above system nav bar and floating "+" action button.
    final guideBottomPadding = safeBottom + 96;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, guideBottomPadding),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(data.body),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(onPressed: onSkip, child: const Text('Skip')),
                      const Spacer(),
                      if (!canProceed)
                        FilledButton.tonal(
                          onPressed: onAction,
                          child: Text(data.actionLabel),
                        )
                      else
                        FilledButton(
                          onPressed: onNext,
                          child: const Text('Next'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

({String title, String body, String actionLabel}) _guideData(int step) {
  switch (step) {
    case 0:
      return (
        title: 'Guide 1/6 - Add Subject',
        body: 'Create your first subject with day and time slots.',
        actionLabel: 'Add Subject',
      );
    case 1:
      return (
        title: 'Guide 2/6 - Expand Card',
        body: 'Tap any subject card to expand quick tools like edit details, reminders, goals, and slots.',
        actionLabel: 'Expand a card',
      );
    case 2:
      return (
        title: 'Guide 3/6 - Forecast',
        body: 'Open Forecast to see your future attendance range.',
        actionLabel: 'Open Forecast',
      );
    case 3:
      return (
        title: 'Guide 4/6 - Mark Today',
        body: 'Mark at least one lecture as Present/Absent.',
        actionLabel: 'Mark now',
      );
    case 4:
      return (
        title: 'Guide 5/6 - Timetable',
        body: 'Open Timetable and check calendar + weekly tabular view (with Free slots).',
        actionLabel: 'Open Timetable',
      );
    case 5:
      return (
        title: 'Guide 6/6 - Settings',
        body: 'Open Settings to personalize theme, reminders and profile.',
        actionLabel: 'Open Settings',
      );
    default:
      return (
        title: 'Guide complete',
        body: 'You can restart this guide anytime from Settings.',
        actionLabel: 'Finish',
      );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _ForecastCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final String idKey;
  final String title;
  final String time;
  final String statusText;
  final Color statusColor;
  final AttendanceStatus? activeStatus;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;
  final VoidCallback onCancel;
  final bool swipeEnabled;
  final VoidCallback? onSwipePresent;
  final VoidCallback? onSwipeAbsent;

  const _LectureCard({
    required this.idKey,
    required this.title,
    required this.time,
    required this.statusText,
    required this.statusColor,
    required this.activeStatus,
    required this.onPresent,
    required this.onAbsent,
    required this.onCancel,
    this.swipeEnabled = true,
    this.onSwipePresent,
    this.onSwipeAbsent,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Expanded(child: Text(time, overflow: TextOverflow.ellipsis)),
                Text(statusText, style: TextStyle(color: statusColor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ActionPill(
                  label: 'Present',
                  color: Colors.green,
                  active: activeStatus == AttendanceStatus.present,
                  onTap: onPresent,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  label: 'Absent',
                  color: Colors.red,
                  active: activeStatus == AttendanceStatus.absent,
                  onTap: onAbsent,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  label: 'Cancel',
                  color: Colors.orange,
                  active: activeStatus == AttendanceStatus.cancelled,
                  onTap: onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!swipeEnabled) return card;

    return Dismissible(
      key: ValueKey(idKey),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onSwipePresent?.call();
        } else if (direction == DismissDirection.endToStart) {
          onSwipeAbsent?.call();
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.check_circle, color: Colors.green),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.cancel, color: Colors.red),
      ),
      child: card,
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: active
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          side: BorderSide(color: active ? color : color.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatusData {
  final String text;
  final Color color;

  _StatusData(this.text, this.color);
}

class _LectureEntry {
  final Subject subject;
  final LectureSlot slot;
  final int slotIndex;
  final int originalWeekday;

  _LectureEntry({
    required this.subject,
    required this.slot,
    required this.slotIndex,
    required this.originalWeekday,
  });
}

