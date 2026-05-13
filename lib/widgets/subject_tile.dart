import 'package:flutter/material.dart';
import '../models/subject.dart';
import 'interactive_card.dart';

class SubjectTile extends StatelessWidget {
  final Subject subject;
  final VoidCallback? onDelete;
  final VoidCallback? onForecast;
  final VoidCallback? onToggleReminder;
  final VoidCallback? onSetGoal;
  final VoidCallback? onEditSlots;
  final bool compact;
  final bool showTrend;
  final bool showForecastHint;

  const SubjectTile({
    super.key,
    required this.subject,
    this.onDelete,
    this.onForecast,
    this.onToggleReminder,
    this.onSetGoal,
    this.onEditSlots,
    this.compact = false,
    this.showTrend = true,
    this.showForecastHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = subject.attendancePercentage;
    final isLow = percentage < 75;
    final canBunk = subject.bunkableCount(
      threshold: subject.goalPercent / 100,
    );
    final streak = subject.streak();
    final weeklyRate = subject.weeklyAttendanceRate();
    final scheme = Theme.of(context).colorScheme;
    final accent = isLow ? const Color(0xFFFFD6D6) : const Color(0xFFD7F6E7);
    final accentText = isLow ? const Color(0xFFB3261E) : const Color(0xFF0F5132);

    return InteractiveCard(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                subject.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "${percentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: accentText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    subject.isHourWise
                        ? "Hours: ${subject.attended}/${subject.total}"
                        : "Classes: ${subject.attended}/${subject.total}",
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (subject.isHourWise) ...[
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: 'Hour-wise',
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ],
                  const SizedBox(width: 12),
                  if (isLow)
                    Text(
                      "Below 75%",
                      style: TextStyle(
                        color: accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subject.total == 0
                    ? "No attendance data yet."
                    : isLow
                        ? subject.isHourWise
                            ? "Attendance below 75%. Focus on attending upcoming hours."
                            : "Attendance below 75%. Focus on attending upcoming classes."
                        : subject.isHourWise
                            ? "You can miss $canBunk more hour${canBunk == 1 ? '' : 's'} and stay above ${subject.goalPercent.toStringAsFixed(0)}%."
                            : "You can miss $canBunk more class${canBunk == 1 ? '' : 'es'} and stay above ${subject.goalPercent.toStringAsFixed(0)}%.",
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (!compact && showTrend) const SizedBox(height: 8),
              if (!compact && showTrend)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      label: streak.count == 0
                          ? "Streak: --"
                          : "Streak: ${streak.count} ${streak.status == AttendanceStatus.present ? 'Present' : 'Absent'}",
                      color: scheme.surfaceContainerHighest,
                    ),
                    _InfoChip(
                      label: "7-day avg: ${weeklyRate.toStringAsFixed(0)}%",
                      color: scheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  TextButton.icon(
                    onPressed: onForecast,
                    icon: const Icon(Icons.auto_graph),
                    label: const Text("Forecast"),
                  ),
                  TextButton.icon(
                    onPressed: onSetGoal,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text("Goal"),
                  ),
                  TextButton.icon(
                    onPressed: onToggleReminder,
                    icon: Icon(
                      subject.remindersEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                    ),
                    label: const Text("Reminders"),
                  ),
                  if (!subject.isHourWise)
                    TextButton.icon(
                      onPressed: onEditSlots,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text("Edit slots"),
                    ),
                ],
              ),
              if (showForecastHint)
                Text(
                  "Target: ${subject.goalPercent.toStringAsFixed(0)}%",
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: Icon(Icons.delete, color: scheme.error),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
