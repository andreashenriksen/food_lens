import 'package:flutter_test/flutter_test.dart';
import 'package:food_lens/src/models/daily_goal.dart';
import 'package:food_lens/src/models/day_summary.dart';
import 'package:food_lens/src/models/diary_entry.dart';
import 'package:food_lens/src/models/nutrients.dart';

DiaryEntry _entry({
  required double kcal,
  required EntryStatus status,
  MealType meal = MealType.lunch,
  double? protein,
}) => DiaryEntry(
  date: DateTime(2026, 8, 10),
  meal: meal,
  status: status,
  name: 'Test',
  amount: 100,
  unit: 'g',
  nutrients: Nutrients(kcal: kcal, protein: protein),
  createdAt: DateTime(2026, 8, 10, 12),
);

void main() {
  const goal = DailyGoal(kcal: 2000);

  group('DaySummary', () {
    test('separates eaten from planned calories', () {
      final summary = DaySummary(
        date: DateTime(2026, 8, 10),
        goal: goal,
        entries: [
          _entry(kcal: 500, status: EntryStatus.eaten),
          _entry(kcal: 300, status: EntryStatus.eaten),
          _entry(kcal: 700, status: EntryStatus.planned),
        ],
      );

      expect(summary.kcalEaten, 800);
      expect(summary.kcalPlanned, 700);
      expect(summary.kcalProjected, 1500);
      // Remaining counts only what was actually eaten...
      expect(summary.kcalRemaining, 1200);
      // ...while the plan-aware figure looks ahead.
      expect(summary.kcalRemainingAfterPlan, 500);
      expect(summary.planExceedsGoal, isFalse);
    });

    test('flags a plan that would break the limit', () {
      final summary = DaySummary(
        date: DateTime(2026, 8, 10),
        goal: goal,
        entries: [
          _entry(kcal: 1500, status: EntryStatus.eaten),
          _entry(kcal: 900, status: EntryStatus.planned),
        ],
      );

      expect(summary.planExceedsGoal, isTrue);
      expect(summary.kcalRemainingAfterPlan, -400);
      // Eating alone has not yet gone over.
      expect(summary.isOverGoal, isFalse);
    });

    test('reports progress past 100 % without clamping', () {
      final summary = DaySummary(
        date: DateTime(2026, 8, 10),
        goal: goal,
        entries: [_entry(kcal: 2500, status: EntryStatus.eaten)],
      );

      expect(summary.isOverGoal, isTrue);
      expect(summary.progress, closeTo(1.25, 0.001));
      expect(summary.kcalRemaining, -500);
    });

    test('breaks totals down per meal', () {
      final summary = DaySummary(
        date: DateTime(2026, 8, 10),
        goal: goal,
        entries: [
          _entry(
            kcal: 400,
            status: EntryStatus.eaten,
            meal: MealType.breakfast,
          ),
          _entry(kcal: 600, status: EntryStatus.eaten, meal: MealType.dinner),
          _entry(kcal: 200, status: EntryStatus.planned, meal: MealType.dinner),
        ],
      );

      expect(summary.nutrientsFor(MealType.breakfast).kcal, 400);
      expect(summary.nutrientsFor(MealType.dinner).kcal, 800);
      expect(
        summary.nutrientsFor(MealType.dinner, status: EntryStatus.eaten).kcal,
        600,
      );
      expect(summary.entriesFor(MealType.snack), isEmpty);
    });

    test('an empty day has zero totals rather than nulls', () {
      final summary = DaySummary(
        date: DateTime(2026, 8, 10),
        goal: goal,
        entries: const [],
      );

      expect(summary.isEmpty, isTrue);
      expect(summary.kcalEaten, 0);
      expect(summary.kcalRemaining, 2000);
    });
  });

  group('DailyGoal', () {
    test('fromSplit converts an energy split into gram targets', () {
      final goal = DailyGoal.fromSplit(
        kcal: 2000,
        proteinPercent: 30,
        carbsPercent: 40,
        fatPercent: 30,
      );

      expect(goal.proteinG, closeTo(150, 0.01)); // 600 kcal / 4
      expect(goal.carbsG, closeTo(200, 0.01)); // 800 kcal / 4
      expect(goal.fatG, closeTo(66.67, 0.01)); // 600 kcal / 9
      expect(goal.hasMacroTargets, isTrue);
    });
  });

  group('estimateDailyCalories', () {
    test('follows Mifflin-St Jeor for maintenance', () {
      // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780; × 1.2 = 2136.
      final kcal = estimateDailyCalories(
        sex: BodySex.male,
        ageYears: 30,
        weightKg: 80,
        heightCm: 180,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.maintain,
      );

      expect(kcal, closeTo(2136, 0.5));
    });

    test('never suggests an unsafely low limit', () {
      final kcal = estimateDailyCalories(
        sex: BodySex.female,
        ageYears: 70,
        weightKg: 45,
        heightCm: 150,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose,
      );

      expect(kcal, greaterThanOrEqualTo(1200));
    });
  });

  group('DateUtilsX', () {
    test('day keys are sortable and round trip', () {
      final key = DateUtilsX.toKey(DateTime(2026, 3, 7, 22, 45));

      expect(key, '2026-03-07');
      expect(DateUtilsX.fromKey(key), DateTime(2026, 3, 7));
    });

    test('strips the time component', () {
      expect(
        DateUtilsX.dayOf(DateTime(2026, 8, 10, 23, 59)),
        DateTime(2026, 8, 10),
      );
    });
  });
}
