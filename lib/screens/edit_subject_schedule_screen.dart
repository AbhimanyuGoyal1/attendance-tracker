import 'package:flutter/material.dart';
import '../models/subject.dart';

class EditSubjectScheduleScreen extends StatefulWidget {
  final Subject subject;

  const EditSubjectScheduleScreen({super.key, required this.subject});

  @override
  State<EditSubjectScheduleScreen> createState() =>
      _EditSubjectScheduleScreenState();
}

class _EditSubjectScheduleScreenState extends State<EditSubjectScheduleScreen> {
  late Map<int, List<LectureSlot>> _weeklySchedule;
  final List<int> _weekdays = [1, 2, 3, 4, 5, 6, 7];
  final List<int> _durations = [1, 2, 3, 4, 5, 6];

  Future<bool> _confirmOutsideStandardTime(
    TimeOfDay start,
    TimeOfDay end,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time outside standard schedule'),
        content: Text(
          'The selected time ${start.format(context)} - ${end.format(context)} is outside the standard schedule (09:00-18:00). Are you sure you want to use this time, or did you mean PM?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Edit Time'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Anyway'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  void initState() {
    super.initState();
    _weeklySchedule = {
      for (final entry in widget.subject.weeklySchedule.entries)
        entry.key: [
          for (final slot in entry.value)
            LectureSlot(start: slot.start, end: slot.end),
        ],
    };
  }

  Future<void> _addTimeSlot(int day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null || !mounted) return;

    final selectedDuration = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Duration (hours)"),
        children: _durations
            .map(
              (h) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, h),
                child: Text("$h hour${h > 1 ? 's' : ''}"),
              ),
            )
            .toList(),
      ),
    );
    if (selectedDuration == null || !mounted) return;

    final rawEndHour = start.hour + selectedDuration;
    if (rawEndHour > 23) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid same-day time slot.')),
      );
      return;
    }
    final end = TimeOfDay(hour: rawEndHour, minute: start.minute);
    final outsideStandard =
        start.hour < 9 || (end.hour > 18 || (end.hour == 18 && end.minute > 0));
    if (outsideStandard) {
      final confirm = await _confirmOutsideStandardTime(start, end);
      if (!confirm || !mounted) return;
    }
    final newStart = start.hour * 60 + start.minute;
    final newEnd = end.hour * 60 + end.minute;
    final slots = _weeklySchedule[day] ?? [];
    final overlaps = slots.any((slot) {
      final s = slot.start.hour * 60 + slot.start.minute;
      final e = slot.end.hour * 60 + slot.end.minute;
      return newStart < e && newEnd > s;
    });

    if (overlaps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This slot overlaps an existing lecture.')),
      );
      return;
    }

    setState(() {
      _weeklySchedule.putIfAbsent(day, () => []);
      _weeklySchedule[day]!.add(LectureSlot(start: start, end: end));
      _weeklySchedule[day]!.sort((a, b) {
        final am = a.start.hour * 60 + a.start.minute;
        final bm = b.start.hour * 60 + b.start.minute;
        return am.compareTo(bm);
      });
    });
  }

  Future<void> _editSlot(int day, int index) async {
    final existing = _weeklySchedule[day]![index];
    final start = await showTimePicker(
      context: context,
      initialTime: existing.start,
    );
    if (start == null || !mounted) return;

    final selectedDuration = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Duration (hours)"),
        children: _durations
            .map(
              (h) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, h),
                child: Text("$h hour${h > 1 ? 's' : ''}"),
              ),
            )
            .toList(),
      ),
    );
    if (selectedDuration == null || !mounted) return;

    final rawEndHour = start.hour + selectedDuration;
    if (rawEndHour > 23) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid same-day time slot.')),
      );
      return;
    }
    final end = TimeOfDay(hour: rawEndHour, minute: start.minute);
    final outsideStandard =
        start.hour < 9 || (end.hour > 18 || (end.hour == 18 && end.minute > 0));
    if (outsideStandard) {
      final confirm = await _confirmOutsideStandardTime(start, end);
      if (!confirm || !mounted) return;
    }
    final newStart = start.hour * 60 + start.minute;
    final newEnd = end.hour * 60 + end.minute;
    final slots = List<LectureSlot>.from(_weeklySchedule[day]!);
    slots.removeAt(index);
    final overlaps = slots.any((slot) {
      final s = slot.start.hour * 60 + slot.start.minute;
      final e = slot.end.hour * 60 + slot.end.minute;
      return newStart < e && newEnd > s;
    });
    if (overlaps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This slot overlaps an existing lecture.')),
      );
      return;
    }
    setState(() {
      _weeklySchedule[day]![index] = LectureSlot(start: start, end: end);
      _weeklySchedule[day]!.sort((a, b) {
        final am = a.start.hour * 60 + a.start.minute;
        final bm = b.start.hour * 60 + b.start.minute;
        return am.compareTo(bm);
      });
    });
  }

  void _removeSlot(int day, int index) {
    setState(() {
      _weeklySchedule[day]!.removeAt(index);
      if (_weeklySchedule[day]!.isEmpty) _weeklySchedule.remove(day);
    });
  }

  void _save() {
    if (_weeklySchedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one lecture slot.')),
      );
      return;
    }
    Navigator.pop(context, _weeklySchedule);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.subject.name}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Schedule',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              ..._weekdays.map((day) {
                final slots = _weeklySchedule[day] ?? [];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _weekdayName(day),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _addTimeSlot(day),
                            ),
                          ],
                        ),
                        if (slots.isEmpty)
                          Text(
                            'No lectures',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ...slots.asMap().entries.map((entry) {
                          final index = entry.key;
                          final slot = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(slot.format(context)),
                            onTap: () => _editSlot(day, index),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: scheme.error),
                              onPressed: () => _removeSlot(day, index),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayName(int day) {
    const names = {
      1: "Monday",
      2: "Tuesday",
      3: "Wednesday",
      4: "Thursday",
      5: "Friday",
      6: "Saturday",
      7: "Sunday",
    };
    return names[day]!;
  }
}
