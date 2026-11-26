import 'daily_goal.dart';
import 'diary_entry.dart';
import 'nutrients.dart';

/// Everything the Today and Plan screens need for a single day, derived once
/// from that day's entries.
class DaySummary {
  DaySummary({required this.date, required this.entries, required this.goal});

  final DateTime date;
  final List<DiaryEntry> entries;
  final DailyGoal goal;

  late final List<DiaryEntry> eatenEntries = entries
      .where((e) => e.status == EntryStatus.eaten)
      .toList();

  late final List<DiaryEntry> plannedEntries = entries
      .where((e) => e.status == EntryStatus.planned)
      .toList();

  /// Nutrients from what has actually been eaten.
  late final Nutrients eaten = Nutrients.sum(
    eatenEntries.map((e) => e.nutrients),
  );

  /// Nutrients from what is still only planned.
  late final Nutrients planned = Nutrients.sum(
    plannedEntries.map((e) => e.nutrients),
  );

  /// What the day totals if every planned item is eaten as scheduled.
  late final Nutrients projected = eaten + planned;

  double get kcalEaten => eaten.kcal ?? 0;
  double get kcalPlanned => planned.kcal ?? 0;
  double get kcalProjected => projected.kcal ?? 0;

  /// Calories left against the goal, counting only what was eaten.
  double get kcalRemaining => goal.kcal - kcalEaten;

  /// Calories left once the rest of the plan is accounted for. Negative means
  /// following the plan would break the limit.
  double get kcalRemainingAfterPlan => goal.kcal - kcalProjected;

  /// Eaten calories as a fraction of the goal, uncapped so the UI can show an
  /// overshoot.
  double get progress => goal.kcal <= 0 ? 0 : kcalEaten / goal.kcal;

  bool get isOverGoal => kcalEaten > goal.kcal;
  bool get planExceedsGoal => kcalProjected > goal.kcal;

  bool get isEmpty => entries.isEmpty;

  List<DiaryEntry> entriesFor(MealType meal, {EntryStatus? status}) => entries
      .where((e) => e.meal == meal && (status == null || e.status == status))
      .toList();

  Nutrients nutrientsFor(MealType meal, {EntryStatus? status}) =>
      Nutrients.sum(entriesFor(meal, status: status).map((e) => e.nutrients));
}
