import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/subject.dart';

class AnalyticsScreen extends StatelessWidget {
  final List<Subject> subjects;

  const AnalyticsScreen({super.key, required this.subjects});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final present = subjects.fold<int>(0, (s, e) => s + e.present);
    final absent = subjects.fold<int>(0, (s, e) => s + e.absent);
    final cancelled = subjects.fold<int>(0, (s, e) => s + e.cancelled);

    final trend = _buildTrend();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: "Overview",
            subtitle: "Attendance distribution",
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFF22C55E),
                            value: present.toDouble(),
                            title: '',
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFEF4444),
                            value: absent.toDouble(),
                            title: '',
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFF59E0B),
                            value: cancelled.toDouble(),
                            title: '',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendRow(
                          color: const Color(0xFF22C55E),
                          label: "Present",
                          value: present,
                        ),
                        const SizedBox(height: 8),
                        _LegendRow(
                          color: const Color(0xFFEF4444),
                          label: "Absent",
                          value: absent,
                        ),
                        const SizedBox(height: 8),
                        _LegendRow(
                          color: const Color(0xFFF59E0B),
                          label: "Cancelled",
                          value: cancelled,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: "Trend",
            subtitle: "Last 14 days",
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        barWidth: 3,
                        color: scheme.primary,
                        belowBarData: BarAreaData(
                          show: true,
                          color: scheme.primary.withValues(alpha: 0.15),
                        ),
                        dotData: const FlDotData(show: false),
                        spots: trend,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/attendance_export_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    final rows = <String>[
      'subject,attended,total,unit,percentage,goal',
      ...subjects.map(
        (s) =>
            '"${s.name}",${s.attended},${s.total},${s.unitLabel},${s.attendancePercentage.toStringAsFixed(2)},${s.goalPercent.toStringAsFixed(0)}',
      ),
    ];
    await file.writeAsString(rows.join('\n'));
    if (!context.mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Attendance export',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV exported and ready to share')),
    );
  }

  List<FlSpot> _buildTrend() {
    final now = DateTime.now();
    final days = List.generate(14, (i) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 13 - i));
      return d;
    });

    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      int present = 0;
      int total = 0;
      for (final subject in subjects) {
        final list = subject.getAttendanceFor(day) ?? [];
        if (subject.isHourWise) {
          final first = list.cast<AttendanceStatus?>().firstWhere(
                (s) => s != null,
                orElse: () => null,
              );
          if (first == null || first == AttendanceStatus.cancelled) continue;
          final hours = subject.hoursForWeekday(day.weekday);
          total += hours;
          if (first == AttendanceStatus.present) present += hours;
          continue;
        }
        for (final status in list) {
          if (status == null || status == AttendanceStatus.cancelled) continue;
          total++;
          if (status == AttendanceStatus.present) present++;
        }
      }
      final rate = total == 0 ? 0.0 : (present / total) * 100;
      spots.add(FlSpot(i.toDouble(), rate));
    }
    return spots;
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

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value.toString()),
      ],
    );
  }
}
