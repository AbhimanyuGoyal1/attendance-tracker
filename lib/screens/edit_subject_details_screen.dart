import 'package:flutter/material.dart';

import '../models/subject.dart';

class EditSubjectDetailsScreen extends StatefulWidget {
  final Subject subject;

  const EditSubjectDetailsScreen({super.key, required this.subject});

  @override
  State<EditSubjectDetailsScreen> createState() =>
      _EditSubjectDetailsScreenState();
}

class _EditSubjectDetailsScreenState extends State<EditSubjectDetailsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _instructorController;
  late bool _isHourWise;
  late final Map<int, TextEditingController> _weeklyHourControllers;
  final List<int> _weekdays = [1, 2, 3, 4, 5, 6, 7];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject.name);
    _codeController = TextEditingController(text: widget.subject.subjectCode);
    _instructorController =
        TextEditingController(text: widget.subject.instructorName);
    _isHourWise = widget.subject.isHourWise;
    _weeklyHourControllers = {
      for (final day in _weekdays)
        day: TextEditingController(
          text: widget.subject.hoursForWeekday(day).toString(),
        ),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _instructorController.dispose();
    for (final controller in _weeklyHourControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject name is required')),
      );
      return;
    }

    final weeklyHours = <int, int>{
      for (final day in _weekdays)
        day: int.tryParse(_weeklyHourControllers[day]!.text.trim()) ?? 0,
    };
    if (_isHourWise && !weeklyHours.values.any((h) => h > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add hours for at least one weekday')),
      );
      return;
    }

    Navigator.pop(context, <String, dynamic>{
      'name': name,
      'subjectCode': _codeController.text.trim(),
      'instructorName': _instructorController.text.trim(),
      'isHourWise': _isHourWise,
      'weeklyHours': weeklyHours,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Subject Details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Subject Code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructorController,
              decoration: const InputDecoration(
                labelText: 'Teacher / Professor',
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isHourWise,
              title: const Text(
                'This subject has hour-wise attendance (variable hours per weekday)',
              ),
              onChanged: (value) =>
                  setState(() => _isHourWise = value ?? false),
            ),
            if (_isHourWise) ...[
              const SizedBox(height: 8),
              ..._weekdays.map((day) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _weekdayName(day),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
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
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
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
    return names[day]!;
  }
}
