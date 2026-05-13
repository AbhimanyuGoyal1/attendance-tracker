import 'package:flutter/material.dart';
import '../models/subject.dart';

class AddSubjectScreen extends StatefulWidget {
  const AddSubjectScreen({super.key});

  @override
  State<AddSubjectScreen> createState() => _AddSubjectScreenState();
}

class _AddSubjectScreenState extends State<AddSubjectScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController instructorController = TextEditingController();
  final TextEditingController presentController = TextEditingController();
  final TextEditingController absentController = TextEditingController();
  Map<int, List<LectureSlot>> weeklySchedule = {};
  bool _isHourWise = false;
  late final Map<int, TextEditingController> _weeklyHourControllers;
  final List<int> weekdays = [1, 2, 3, 4, 5, 6, 7];
  final List<int> durations = [1, 2, 3, 4, 5, 6]; // hours
  bool get _hasUnsavedChanges =>
      nameController.text.trim().isNotEmpty ||
      codeController.text.trim().isNotEmpty ||
      instructorController.text.trim().isNotEmpty ||
      _isHourWise ||
      weeklySchedule.isNotEmpty ||
      _weeklyHours.values.any((h) => h > 0) ||
      presentController.text.trim().isNotEmpty ||
      absentController.text.trim().isNotEmpty;

  Map<int, int> get _weeklyHours => {
    for (final day in weekdays)
      day: int.tryParse(_weeklyHourControllers[day]!.text.trim()) ?? 0,
  };

  @override
  void initState() {
    super.initState();
    _weeklyHourControllers = {
      for (final day in weekdays) day: TextEditingController(text: '0'),
    };
  }

  Future<void> _addTimeSlot(int day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null) return;
    if (!mounted) return;

    final selectedDuration = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Select Duration (hours)"),
          children: durations
              .map(
                (h) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, h),
                  child: Text("$h hour${h > 1 ? 's' : ''}"),
                ),
              )
              .toList(),
        );
      },
    );
    if (selectedDuration == null) return;
    if (!mounted) return;

    final rawEndHour = start.hour + selectedDuration;
    if (rawEndHour > 23) {
      if (!mounted) return;
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
      if (!confirm) return;
      if (!mounted) return;
    }
    final newStart = start.hour * 60 + start.minute;
    final newEnd = end.hour * 60 + end.minute;
    final slots = weeklySchedule[day] ?? [];
    final overlaps = slots.any((slot) {
      final s = slot.start.hour * 60 + slot.start.minute;
      final e = slot.end.hour * 60 + slot.end.minute;
      return newStart < e && newEnd > s;
    });
    if (overlaps) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This slot overlaps an existing lecture.')),
      );
      return;
    }

    setState(() {
      weeklySchedule.putIfAbsent(day, () => []);
      weeklySchedule[day]!.add(LectureSlot(start: start, end: end));
    });
  }

  void _removeSlot(int day, int index) {
    setState(() {
      weeklySchedule[day]!.removeAt(index);
      if (weeklySchedule[day]!.isEmpty) weeklySchedule.remove(day);
    });
  }

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

  bool _canSave() =>
      nameController.text.trim().isNotEmpty &&
      (_isHourWise
          ? _weeklyHours.values.any((hours) => hours > 0)
          : weeklySchedule.isNotEmpty);

  Future<void> _saveAndClose() async {
    if (!_canSave()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHourWise
                ? 'Enter subject name and add hours for at least one weekday.'
                : 'Enter subject name and add at least one lecture slot.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      Subject(
        name: nameController.text.trim(),
        subjectCode: codeController.text.trim(),
        instructorName: instructorController.text.trim(),
        weeklySchedule: weeklySchedule,
        carryPresent: int.tryParse(presentController.text.trim()) ?? 0,
        carryAbsent: int.tryParse(absentController.text.trim()) ?? 0,
        isHourWise: _isHourWise,
        weeklyHours: _weeklyHours,
      ),
    );
  }

  Future<void> _confirmExitIfNeeded() async {
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save subject?'),
        content: const Text(
          'You have unsaved changes. Save this subject before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: _canSave() ? () => Navigator.pop(context, true) : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      await _saveAndClose();
      return;
    }
    if (shouldSave == false && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmExitIfNeeded();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Add Subject"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmExitIfNeeded,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Create a subject",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Add weekly lecture slots to generate your timetable.",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Subject Name",
                hintText: "e.g. Calculus",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Subject Code",
                hintText: "e.g. CSE201",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instructorController,
              decoration: const InputDecoration(
                labelText: "Teacher / Professor",
                hintText: "e.g. Dr. Sharma",
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isHourWise,
              title: const Text(
                'This subject has hour-wise attendance (variable hours per weekday)',
              ),
              onChanged: (value) => setState(() => _isHourWise = value ?? false),
            ),
            const SizedBox(height: 8),
            Text(
              "Existing attendance (optional)",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: presentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isHourWise
                          ? "Already attended hours"
                          : "Already present classes",
                      hintText: "0",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: absentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isHourWise
                          ? "Already missed hours"
                          : "Already absent classes",
                      hintText: "0",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isHourWise) ...[
              Text(
                "Weekly Hours",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                "Enter scheduled hours for each weekday.",
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              ...weekdays.map((day) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(
                      _weekdayName(day),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _weeklyHourControllers[day],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          suffixText: 'hrs',
                          hintText: '0',
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ] else ...[
              Text(
                "Weekly Schedule",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              ...weekdays.map((day) {
                final slots = weeklySchedule[day] ?? [];
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
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _addTimeSlot(day),
                            ),
                          ],
                        ),
                        if (slots.isEmpty)
                          Text(
                            "No lectures",
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ...slots.asMap().entries.map((entry) {
                          final index = entry.key;
                          final slot = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(slot.format(context)),
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
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAndClose,
                child: const Text("Add Subject"),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    instructorController.dispose();
    presentController.dispose();
    absentController.dispose();
    for (final controller in _weeklyHourControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
