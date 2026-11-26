import 'package:flutter/material.dart';

import '../../models/diary_entry.dart';
import '../format.dart';

/// One logged or planned item in a meal list.
///
/// Swiping left deletes; the leading control ticks a planned item off as
/// eaten, which is the main gesture on the plan screen.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onDelete,
    this.onToggleEaten,
    this.onTap,
  });

  final DiaryEntry entry;
  final VoidCallback onDelete;
  final VoidCallback? onToggleEaten;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = entry.isPlanned;
    final subtitleParts = <String>[
      formatAmount(entry.amount, entry.unit),
      if (entry.brand != null && entry.brand!.isNotEmpty) entry.brand!,
    ];

    return Dismissible(
      key: ValueKey(entry.id ?? entry.hashCode),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        leading: onToggleEaten == null
            ? null
            : IconButton(
                tooltip: planned
                    ? 'Marker som spist'
                    : 'Flytt tilbake til plan',
                icon: Icon(
                  planned
                      ? Icons.radio_button_unchecked
                      : Icons.check_circle_rounded,
                  color: planned
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                ),
                onPressed: onToggleEaten,
              ),
        title: Text(
          entry.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: planned ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${formatKcal(entry.nutrients.kcal)} kcal',
              style: theme.textTheme.titleSmall?.copyWith(
                color: planned ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
            if (entry.nutrients.protein != null)
              Text(
                'P ${formatGrams(entry.nutrients.protein)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Header above each meal group, showing that meal's calorie subtotal.
class MealHeader extends StatelessWidget {
  const MealHeader({
    super.key,
    required this.meal,
    required this.kcal,
    required this.onAdd,
  });

  final MealType meal;
  final double kcal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
      child: Row(
        children: [
          Text(meal.label, style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Text(
            '${formatKcal(kcal)} kcal',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Legg til i ${meal.label.toLowerCase()}',
            icon: const Icon(Icons.add_rounded),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
