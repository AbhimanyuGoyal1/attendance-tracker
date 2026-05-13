import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class OnboardingScreen extends StatefulWidget {
  final ValueChanged<AppSettings> onComplete;
  final AppSettings current;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    required this.current,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  double _goal = 75;
  bool _reminders = true;
  bool _swipeActions = true;

  @override
  void initState() {
    super.initState();
    _swipeActions = widget.current.enableSwipeActions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Text(
                'Quick Setup',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Set defaults for cleaner daily tracking.'),
              const SizedBox(height: 24),
              Text('Default attendance goal: ${_goal.toStringAsFixed(0)}%'),
              Slider(
                min: 60,
                max: 95,
                divisions: 7,
                value: _goal,
                onChanged: (v) => setState(() => _goal = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable reminders by default'),
                value: _reminders,
                onChanged: (v) => setState(() => _reminders = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable swipe actions'),
                value: _swipeActions,
                onChanged: (v) => setState(() => _swipeActions = v),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final updated = AppSettings.fromMap(widget.current.toMap());
                    updated.onboardingCompleted = true;
                    updated.enableSwipeActions = _swipeActions;
                    updated.defaultSubjectReminderEnabled = _reminders;
                    updated.defaultGoalPercent = _goal;
                    widget.onComplete(updated);
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
