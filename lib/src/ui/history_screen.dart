import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/diary_entry.dart';
import '../state/diary_controller.dart';
import 'format.dart';

/// Calories eaten over the last two weeks, against the current goal.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const int _days = 14;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiaryController>();
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, double>>(
      // Rebuilds whenever the controller notifies, so logging an item on the
      // Today tab refreshes the chart without extra plumbing.
      future: controller.kcalHistory(days: _days),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final totals = snapshot.data!;
        final today = DateUtilsX.dayOf(DateTime.now());
        final days = List.generate(
          _days,
          (i) => today.subtract(Duration(days: _days - 1 - i)),
        );
        final goal = controller.goal.kcal;

        final logged = days
            .map((d) => totals[DateUtilsX.toKey(d)] ?? 0)
            .where((v) => v > 0)
            .toList();
        final average = logged.isEmpty
            ? 0.0
            : logged.reduce((a, b) => a + b) / logged.length;
        final withinGoal = logged.where((v) => v <= goal).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _Stat(
                      label: 'Snitt per dag',
                      value: '${formatKcal(average)} kcal',
                    ),
                    _Stat(
                      label: 'Dager innenfor',
                      value: '$withinGoal / ${logged.length}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Siste $_days dager', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: _BarChart(
                days: days,
                totals: totals,
                goal: goal,
                onTapDay: controller.selectDay,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  'Grense: ${formatKcal(goal)} kcal',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (logged.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  'Ingen registreringer ennå. Når du logger mat dukker det opp her.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// A plain bar chart. Bars over the goal are drawn in the error colour, and
/// the goal itself is a dashed reference line.
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.days,
    required this.totals,
    required this.goal,
    required this.onTapDay,
  });

  final List<DateTime> days;
  final Map<String, double> totals;
  final double goal;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = days.map((d) => totals[DateUtilsX.toKey(d)] ?? 0).toList();
    // Scale to whichever is larger, the goal line or the biggest bar, so
    // neither ever runs off the top.
    final maxValue = [
      goal,
      ...values,
    ].reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxHeight - 24;
        final goalOffset = chartHeight * (1 - goal / maxValue);

        return Stack(
          children: [
            Positioned(
              top: goalOffset,
              left: 0,
              right: 0,
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outline,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onTapDay(days[i]),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: (chartHeight * (values[i] / maxValue))
                                .clamp(0.0, chartHeight),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: values[i] > goal
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${days[i].day}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
