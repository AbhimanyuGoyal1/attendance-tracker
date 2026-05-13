import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/subject.dart';

class TimetableScreen extends StatefulWidget {
  final List<Subject> subjects;
  final VoidCallback? onChanged;

  const TimetableScreen({
    super.key,
    required this.subjects,
    this.onChanged,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _focusedDay = _normalizeDate(DateTime.now());
  DateTime _selectedDay = _normalizeDate(DateTime.now());
  bool _showWeekGrid = false;

  static DateTime _normalizeDate(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    return DateTime(local.year, local.month, local.day);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lecturesToday = widget.subjects.expand((subject) {
      final slots = subject.getSlotsFor(_selectedDay);
      return List.generate(
        slots.length,
        (i) => _LectureEntry(
          subject: subject,
          slotIndex: i,
          originalDate: subject.getOriginalDate(_selectedDay, i),
        ),
      );
    }).toList()
      ..sort((a, b) {
        final slotA = a.subject.getSlotsFor(_selectedDay)[a.slotIndex].start;
        final slotB = b.subject.getSlotsFor(_selectedDay)[b.slotIndex].start;
        final aMinutes = slotA.hour * 60 + slotA.minute;
        final bMinutes = slotB.hour * 60 + slotB.minute;
        if (aMinutes != bMinutes) return aMinutes.compareTo(bMinutes);
        return a.subject.name.toLowerCase().compareTo(b.subject.name.toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Timetable"),
        actions: [
          if (lecturesToday.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.beach_access),
              tooltip: "Declare Holiday",
              onPressed: () => _confirmDeclareHoliday(lecturesToday),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'holiday_range') {
                _declareHolidayRange();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'holiday_range',
                child: Text("Holiday Range"),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF22C55E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Selected Day",
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      Text(
                        "${_selectedDay.month}/${_selectedDay.day}/${_selectedDay.year}",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${lecturesToday.length} lectures",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ViewToggle(
            value: _showWeekGrid,
            onChanged: (v) => setState(() => _showWeekGrid = v),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _showWeekGrid
                  ? _WeeklyGrid(
                      subjects: widget.subjects,
                      anchorDay: _selectedDay,
                    )
                  : TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = _normalizeDate(selectedDay);
                          _focusedDay = _normalizeDate(focusedDay);
                        });
                      },
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFF146C94),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: "Lectures",
            subtitle: lecturesToday.isEmpty
                ? "No lectures scheduled"
                : "Tap to update status",
          ),
          const SizedBox(height: 8),
          if (lecturesToday.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "No lectures scheduled for this day.",
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...lecturesToday.map((entry) {
              final subject = entry.subject;
              final slot = subject.getSlotsFor(
                _selectedDay,
              )[entry.slotIndex];
              final status = subject.getAttendanceFor(
                _selectedDay,
              )?[entry.slotIndex];

              final isRescheduled = !isSameDay(
                _selectedDay,
                entry.originalDate,
              );

              final statusData = _statusData(status, isRescheduled);

              return _LectureCard(
                idKey:
                    '${subject.id}_${_selectedDay.toIso8601String()}_${entry.slotIndex}',
                title: _subjectLabel(subject),
                time: slot.format(context),
                statusText: statusData.text,
                statusColor: statusData.color,
                activeStatus: status,
                onPresent: () => _mark(
                  subject,
                  entry.slotIndex,
                  AttendanceStatus.present,
                ),
                onAbsent: () => _mark(
                  subject,
                  entry.slotIndex,
                  AttendanceStatus.absent,
                ),
                onCancel: () => _handleCancelOrReschedule(
                  subject,
                  entry.slotIndex,
                  slot,
                ),
                onClear: () => _mark(subject, entry.slotIndex, null),
                onSwipePresent: () => _mark(
                  subject,
                  entry.slotIndex,
                  AttendanceStatus.present,
                ),
                onSwipeAbsent: () => _mark(
                  subject,
                  entry.slotIndex,
                  AttendanceStatus.absent,
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _confirmDeclareHoliday(List<_LectureEntry> lectures) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Declare Holiday?"),
        content: const Text(
          "Are you sure you want to declare a holiday for today? All lectures will be cancelled.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (confirmed == true) {
      setState(() {
        for (var entry in lectures) {
          entry.subject.markAttendance(
            _selectedDay,
            entry.slotIndex,
            AttendanceStatus.cancelled,
          );
        }
      });
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Holiday declared for the day!")),
      );
    }
  }

  Future<void> _declareHolidayRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: _selectedDay,
        end: _selectedDay,
      ),
    );
    if (!mounted) return;
    if (range == null) return;

    setState(() {
      for (final subject in widget.subjects) {
        subject.markHolidayRange(range.start, range.end);
      }
    });
    widget.onChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Holiday range applied.")),
    );
  }

  _StatusData _statusData(AttendanceStatus? status, bool isRescheduled) {
    switch (status) {
      case AttendanceStatus.present:
        return _StatusData(
          isRescheduled ? "Present (Rescheduled)" : "Present",
          Colors.green,
          Icons.check_circle,
        );
      case AttendanceStatus.absent:
        return _StatusData(
          isRescheduled ? "Absent (Rescheduled)" : "Absent",
          Colors.red,
          Icons.cancel,
        );
      case AttendanceStatus.cancelled:
        return _StatusData(
          isRescheduled ? "Cancelled (Rescheduled)" : "Cancelled",
          Colors.orange,
          Icons.block,
        );
      default:
        return _StatusData(
          isRescheduled ? "Not marked (Rescheduled)" : "Not marked",
          Colors.grey,
          Icons.radio_button_unchecked,
        );
    }
  }

  void _mark(Subject subject, int slotIndex, AttendanceStatus? status) {
    setState(() {
      subject.markAttendance(_selectedDay, slotIndex, status);
    });
    widget.onChanged?.call();
  }

  Future<void> _handleCancelOrReschedule(
    Subject subject,
    int slotIndex,
    LectureSlot slot,
  ) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: _selectedDay,
      lastDate: DateTime(_selectedDay.year + 1),
      helpText: "Select new date to reschedule",
    );
    if (!mounted) return;

    if (newDate != null) {
      final newStart = await showTimePicker(
        context: context,
        initialTime: slot.start,
      );
      if (!mounted) return;
      if (newStart != null) {
        final durationMinutes = _durationInMinutes(slot.start, slot.end);
        final newEnd = _addMinutes(newStart, durationMinutes);
        final newSlot = LectureSlot(start: newStart, end: newEnd);

        setState(() {
          subject.rescheduleLecture(_selectedDay, slotIndex, newDate, newSlot);
          subject.markAttendance(
            _selectedDay,
            slotIndex,
            AttendanceStatus.cancelled,
          );
        });
        widget.onChanged?.call();
        return;
      }
    }

    setState(() {
      subject.markAttendance(
        _selectedDay,
        slotIndex,
        AttendanceStatus.cancelled,
      );
    });
    widget.onChanged?.call();
  }

  int _durationInMinutes(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final delta = (endMinutes - startMinutes) % (24 * 60);
    return delta == 0 ? 24 * 60 : delta;
  }

  TimeOfDay _addMinutes(TimeOfDay start, int minutes) {
    final total = (start.hour * 60 + start.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  String _subjectLabel(Subject subject) {
    final code = subject.subjectCode.trim();
    if (code.isEmpty) return subject.name;
    return '$code - ${subject.name}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
  final VoidCallback onClear;
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
    required this.onClear,
    this.onSwipePresent,
    this.onSwipeAbsent,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(time),
                  const Spacer(),
                  Text(
                    statusText,
                    style: TextStyle(color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ActionPill(
                    label: "Present",
                    color: Colors.green,
                    active: activeStatus == AttendanceStatus.present,
                    onTap: onPresent,
                  ),
                  const SizedBox(width: 8),
                  _ActionPill(
                    label: "Absent",
                    color: Colors.red,
                    active: activeStatus == AttendanceStatus.absent,
                    onTap: onAbsent,
                  ),
                  const SizedBox(width: 8),
                  _ActionPill(
                    label: "Cancel",
                    color: Colors.orange,
                    active: activeStatus == AttendanceStatus.cancelled,
                    onTap: onCancel,
                  ),
                  const SizedBox(width: 8),
                  _ActionPill(
                    label: "Clear",
                    color: Colors.grey,
                    active: activeStatus == null,
                    onTap: onClear,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          backgroundColor: active ? color.withValues(alpha: 0.12) : Colors.transparent,
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

class _ViewToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: false,
          label: Text("Calendar"),
          icon: Icon(Icons.calendar_month),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text("Week"),
          icon: Icon(Icons.view_week),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _WeeklyGrid extends StatelessWidget {
  final List<Subject> subjects;
  final DateTime anchorDay;

  const _WeeklyGrid({required this.subjects, required this.anchorDay});

  @override
  Widget build(BuildContext context) {
    // Kept for future week-specific expansion; grid structure itself is fixed.
    final _ = anchorDay;
    const startHour = 9;
    const endHour = 18;
    const slotLabels = [
      '09:00-10:00',
      '10:00-11:00',
      '11:00-12:00',
      '12:00-13:00',
      '13:00-14:00',
      '14:00-15:00',
      '15:00-16:00',
      '16:00-17:00',
      '17:00-18:00',
    ];
    const slotCount = 9;
    const weekdays = [1, 2, 3, 4, 5];
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    const dayColumnWidth = 84.0;
    const slotColumnWidth = 132.0;
    const rowHeight = 56.0;
    const headerHeight = 44.0;

    final occupied = List.generate(
      weekdays.length,
      (_) => List<bool>.filled(slotCount, false),
    );
    final blocks = <_WeekBlock>[];
    final rejected = <String>[];

    int? dayIndexFromWeekday(int weekday) {
      final i = weekdays.indexOf(weekday);
      return i >= 0 ? i : null;
    }

    for (final subject in subjects) {
      for (final entry in subject.weeklySchedule.entries) {
        final dayIndex = dayIndexFromWeekday(entry.key);
        if (dayIndex == null) continue;

        for (final slot in entry.value) {
          final startsOnHour = slot.start.minute == 0;
          final endsOnHour = slot.end.minute == 0;
          if (!startsOnHour || !endsOnHour) {
            rejected.add(
              '${subject.name} (${slot.format(context)}) - not aligned to 1-hour slots',
            );
            continue;
          }

          final duration = slot.end.hour - slot.start.hour;
          final startSlotIndex = slot.start.hour - startHour;
          final validRange =
              slot.start.hour >= startHour &&
              slot.end.hour <= endHour &&
              duration > 0 &&
              startSlotIndex >= 0 &&
              (startSlotIndex + duration) <= slotCount;

          if (!validRange) {
            rejected.add(
              '${subject.name} (${slot.format(context)}) - outside 09:00-18:00 grid',
            );
            continue;
          }

          var hasConflict = false;
          for (var i = 0; i < duration; i++) {
            if (occupied[dayIndex][startSlotIndex + i]) {
              hasConflict = true;
              break;
            }
          }
          if (hasConflict) {
            rejected.add(
              '${subject.name} (${slot.format(context)}) - conflicts with another lecture',
            );
            continue;
          }

          for (var i = 0; i < duration; i++) {
            occupied[dayIndex][startSlotIndex + i] = true;
          }

          final title = subject.subjectCode.trim().isEmpty
              ? subject.name
              : '${subject.subjectCode} - ${subject.name}';

          blocks.add(
            _WeekBlock(
              dayIndex: dayIndex,
              slotIndex: startSlotIndex,
              duration: duration,
              label: title,
              subtitle: slot.format(context),
            ),
          );
        }
      }
    }

    blocks.sort((a, b) {
      final c = a.dayIndex.compareTo(b.dayIndex);
      if (c != 0) return c;
      return a.slotIndex.compareTo(b.slotIndex);
    });

    final totalWidth = dayColumnWidth + (slotColumnWidth * slotCount);
    final totalHeight = rowHeight * dayLabels.length;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    Widget baseCell({
      required String text,
      required double width,
      required double height,
      FontWeight weight = FontWeight.w500,
      Color? color,
    }) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: borderColor)),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: weight,
                color: color,
              ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: totalWidth,
            child: Row(
              children: [
                baseCell(
                  text: 'Day',
                  width: dayColumnWidth,
                  height: headerHeight,
                  weight: FontWeight.w700,
                ),
                ...slotLabels.map(
                  (slot) => baseCell(
                    text: slot,
                    width: slotColumnWidth,
                    height: headerHeight,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Stack(
              children: [
                Column(
                  children: List.generate(dayLabels.length, (dayIndex) {
                    return Row(
                      children: [
                        baseCell(
                          text: dayLabels[dayIndex],
                          width: dayColumnWidth,
                          height: rowHeight,
                          weight: FontWeight.w600,
                        ),
                        ...List.generate(
                          slotCount,
                          (_) => baseCell(
                            text: 'Free',
                            width: slotColumnWidth,
                            height: rowHeight,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                ...blocks.map((block) {
                  return Positioned(
                    left: dayColumnWidth + (block.slotIndex * slotColumnWidth),
                    top: block.dayIndex * rowHeight,
                    width: block.duration * slotColumnWidth,
                    height: rowHeight,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            block.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            block.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (rejected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Rejected slots:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            ...rejected.take(5).map(
                  (e) => Text(
                    '- $e',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _WeekBlock {
  final int dayIndex;
  final int slotIndex;
  final int duration;
  final String label;
  final String subtitle;

  _WeekBlock({
    required this.dayIndex,
    required this.slotIndex,
    required this.duration,
    required this.label,
    required this.subtitle,
  });
}
/// Helper class for lectures
class _LectureEntry {
  final Subject subject;
  final int slotIndex;
  final DateTime originalDate;

  _LectureEntry({
    required this.subject,
    required this.slotIndex,
    required this.originalDate,
  });
}

class _StatusData {
  final String text;
  final Color color;
  final IconData icon;
  _StatusData(this.text, this.color, this.icon);
}

