import 'package:flutter/material.dart';

import '../../models/daily_goal.dart';
import '../../models/nutrients.dart';
import '../format.dart';
import '../theme.dart';

/// Protein / carbohydrate / fat progress against the day's targets.
///
/// When no macro targets are set the same widget degrades to plain totals, so
/// people who only track calories are not shown empty progress bars.
class MacroBars extends StatelessWidget {
  const MacroBars({super.key, required this.eaten, required this.goal});

  final Nutrients eaten;
  final DailyGoal goal;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _MacroRow(
        label: 'Protein',
        color: FoodLensColors.protein,
        value: eaten.protein,
        target: goal.proteinG,
      ),
      _MacroRow(
        label: 'Karbo',
        color: FoodLensColors.carbs,
        value: eaten.carbs,
        target: goal.carbsG,
      ),
      _MacroRow(
        label: 'Fett',
        color: FoodLensColors.fat,
        value: eaten.fat,
        target: goal.fatG,
      ),
    ];

    return Row(children: [for (final row in rows) Expanded(child: row)]);
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.color,
    required this.value,
    required this.target,
  });

  final String label;
  final Color color;
  final double? value;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eaten = value ?? 0;
    final hasTarget = target != null && target! > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: hasTarget ? (eaten / target!).clamp(0.0, 1.0) : 0,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasTarget
                ? '${formatGrams(eaten)} / ${formatGrams(target)}'
                : formatGrams(value),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact nutrition table for the product screen.
class NutritionTable extends StatelessWidget {
  const NutritionTable({
    super.key,
    required this.nutrients,
    required this.header,
  });

  final Nutrients nutrients;

  /// Describes the basis of the numbers, e.g. "Per 100 g" or "Per porsjon".
  final String header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String, bool)>[
      ('Energi', '${formatKcal(nutrients.kcal)} kcal', true),
      ('Fett', formatGrams(nutrients.fat), true),
      ('– hvorav mettet', formatGrams(nutrients.saturatedFat), false),
      ('Karbohydrater', formatGrams(nutrients.carbs), true),
      ('– hvorav sukkerarter', formatGrams(nutrients.sugars), false),
      ('Kostfiber', formatGrams(nutrients.fiber), true),
      ('Protein', formatGrams(nutrients.protein), true),
      ('Salt', formatGrams(nutrients.salt), true),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Text(
                header,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final (label, value, isPrimary) in rows)
          Padding(
            padding: EdgeInsets.only(left: isPrimary ? 0 : 12, top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: isPrimary
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
                Text(
                  value,
                  style:
                      (isPrimary
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodySmall)
                          ?.copyWith(
                            fontWeight: isPrimary
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isPrimary
                                ? null
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
