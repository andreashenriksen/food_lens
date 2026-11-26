import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/diary_entry.dart';
import '../state/diary_controller.dart';
import 'add_food_flow.dart';
import 'format.dart';
import 'widgets/calorie_ring.dart';
import 'widgets/day_switcher.dart';
import 'widgets/entry_tile.dart';
import 'widgets/load_failure.dart';
import 'widgets/macro_bars.dart';

/// The diary: what has been eaten today, grouped by meal, against the limit.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiaryController>();
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null) {
      return LoadFailure(error: controller.error!, onRetry: controller.retry);
    }

    final summary = controller.summary;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const DaySwitcher(),
        const SizedBox(height: 8),
        Center(
          child: CalorieRing(
            eaten: summary.kcalEaten,
            planned: summary.kcalPlanned,
            goal: controller.goal.kcal,
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: MacroBars(eaten: summary.eaten, goal: controller.goal),
        ),
        if (summary.kcalPlanned > 0) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PlanBanner(
              plannedKcal: summary.kcalPlanned,
              remainingAfterPlan: summary.kcalRemainingAfterPlan,
              exceeds: summary.planExceedsGoal,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final meal in MealType.values)
          _MealSection(meal: meal, controller: controller),
        if (summary.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ingenting registrert ennå.\nTrykk «Legg til» for å skanne eller søke.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlanBanner extends StatelessWidget {
  const _PlanBanner({
    required this.plannedKcal,
    required this.remainingAfterPlan,
    required this.exceeds,
  });

  final double plannedKcal;
  final double remainingAfterPlan;
  final bool exceeds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = exceeds
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final onColor = exceeds
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            exceeds
                ? Icons.warning_amber_rounded
                : Icons.event_available_rounded,
            color: onColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exceeds
                  ? 'Planen for resten av dagen ligger ${formatKcal(remainingAfterPlan.abs())} kcal over grensen.'
                  : 'Planlagt igjen: ${formatKcal(plannedKcal)} kcal. '
                        'Da har du ${formatKcal(remainingAfterPlan)} kcal til overs.',
              style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal, required this.controller});

  final MealType meal;
  final DiaryController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.summary.entriesFor(meal);
    if (entries.isEmpty) return const SizedBox.shrink();

    final kcal =
        controller.summary.nutrientsFor(meal, status: EntryStatus.eaten).kcal ??
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealHeader(
          meal: meal,
          kcal: kcal,
          onAdd: () => showAddFoodFlow(
            context,
            controller: controller,
            status: EntryStatus.eaten,
            meal: meal,
          ),
        ),
        for (final entry in entries)
          EntryTile(
            entry: entry,
            onToggleEaten: () => entry.isPlanned
                ? controller.markEaten(entry)
                : controller.markPlanned(entry),
            onDelete: () => _deleteWithUndo(context, controller, entry),
          ),
      ],
    );
  }

  void _deleteWithUndo(
    BuildContext context,
    DiaryController controller,
    DiaryEntry entry,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    controller.deleteEntry(entry);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${entry.name} slettet'),
        action: SnackBarAction(
          label: 'Angre',
          onPressed: () => controller.restoreEntry(entry),
        ),
      ),
    );
  }
}
