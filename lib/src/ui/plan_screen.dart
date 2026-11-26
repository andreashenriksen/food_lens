import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/diary_entry.dart';
import '../state/diary_controller.dart';
import 'add_food_flow.dart';
import 'format.dart';
import 'widgets/day_switcher.dart';
import 'widgets/entry_tile.dart';
import 'widgets/load_failure.dart';

/// The day plan: what the user intends to eat, and whether it fits the limit.
///
/// Planned items live in the same list as eaten ones, so ticking one off here
/// immediately moves the calories into the Today totals.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _BudgetCard(
            goal: controller.goal.kcal,
            eaten: summary.kcalEaten,
            planned: summary.kcalPlanned,
            remaining: summary.kcalRemainingAfterPlan,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Kopier i går'),
                  onPressed: () => _copyYesterday(context, controller),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Alt spist'),
                  onPressed: summary.plannedEntries.isEmpty
                      ? null
                      : () => controller.completeWholePlan(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final meal in MealType.values)
          _PlanMealSection(meal: meal, controller: controller),
        if (summary.plannedEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ingen plan for ${formatDayLabel(controller.selectedDay).toLowerCase()}.\n'
                  'Legg inn måltidene du har tenkt å spise, så ser du med én gang '
                  'om de holder seg innenfor grensen.',
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

  Future<void> _copyYesterday(
    BuildContext context,
    DiaryController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final source = controller.selectedDay.subtract(const Duration(days: 1));
    final count = await controller.copyDayInto(source);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Fant ingenting å kopiere fra ${formatShortDate(source)}.'
              : 'Kopierte $count elementer fra ${formatShortDate(source)}.',
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.goal,
    required this.eaten,
    required this.planned,
    required this.remaining,
  });

  final double goal;
  final double eaten;
  final double planned;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = remaining < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Figure(label: 'Grense', value: goal),
                _Figure(label: 'Spist', value: eaten),
                _Figure(label: 'Planlagt', value: planned),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  over
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline,
                  size: 20,
                  color: over
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    over
                        ? 'Planen sprenger grensen med ${formatKcal(remaining.abs())} kcal.'
                        : 'Rom igjen etter planen: ${formatKcal(remaining)} kcal.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: over ? theme.colorScheme.error : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final double value;

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
          const SizedBox(height: 2),
          Text(
            formatKcal(value),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanMealSection extends StatelessWidget {
  const _PlanMealSection({required this.meal, required this.controller});

  final MealType meal;
  final DiaryController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.summary.entriesFor(
      meal,
      status: EntryStatus.planned,
    );
    if (entries.isEmpty) return const SizedBox.shrink();

    final kcal =
        controller.summary
            .nutrientsFor(meal, status: EntryStatus.planned)
            .kcal ??
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
            status: EntryStatus.planned,
            meal: meal,
          ),
        ),
        for (final entry in entries)
          EntryTile(
            entry: entry,
            onToggleEaten: () => controller.markEaten(entry),
            onDelete: () => controller.deleteEntry(entry),
          ),
      ],
    );
  }
}
