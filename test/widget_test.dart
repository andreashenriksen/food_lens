import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_lens/src/models/daily_goal.dart';
import 'package:food_lens/src/models/nutrients.dart';
import 'package:food_lens/src/ui/format.dart';
import 'package:food_lens/src/ui/theme.dart';
import 'package:food_lens/src/ui/widgets/calorie_ring.dart';
import 'package:food_lens/src/ui/widgets/macro_bars.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('CalorieRing', () {
    testWidgets('shows calories left against the goal', (tester) async {
      await tester.pumpWidget(
        _wrap(const CalorieRing(eaten: 1200, planned: 0, goal: 2000)),
      );

      expect(find.text('800'), findsOneWidget);
      expect(find.text('kcal igjen'), findsOneWidget);
      // Built from the formatter rather than a literal: the nb_NO grouping
      // separator is a non-breaking space, not an ordinary one.
      expect(
        find.text('${formatKcal(1200)} / ${formatKcal(2000)}'),
        findsOneWidget,
      );
    });

    testWidgets('switches to an overshoot reading past the goal', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CalorieRing(eaten: 2300, planned: 0, goal: 2000)),
      );

      expect(find.text('300'), findsOneWidget);
      expect(find.text('kcal over'), findsOneWidget);
    });
  });

  group('MacroBars', () {
    testWidgets('shows progress against targets when they are set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MacroBars(
            eaten: Nutrients(protein: 60, carbs: 100, fat: 30),
            goal: DailyGoal(kcal: 2000, proteinG: 150, carbsG: 200, fatG: 67),
          ),
        ),
      );

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('60 g / 150 g'), findsOneWidget);
    });

    testWidgets('falls back to plain totals without targets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroBars(
            eaten: Nutrients(protein: 60),
            goal: DailyGoal(kcal: 2000),
          ),
        ),
      );

      expect(find.text('60 g'), findsOneWidget);
      // Undeclared macros read as a dash rather than a misleading zero.
      expect(find.text('–'), findsNWidgets(2));
    });
  });

  group('NutritionTable', () {
    testWidgets('renders a declaration with its basis', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SingleChildScrollView(
            child: NutritionTable(
              nutrients: Nutrients(kcal: 271, fat: 12.5, saturatedFat: 7.2),
              header: 'Per 100 g',
            ),
          ),
        ),
      );

      expect(find.text('Per 100 g'), findsOneWidget);
      expect(find.text('271 kcal'), findsOneWidget);
      expect(find.text('12,5 g'), findsOneWidget);
      expect(find.text('– hvorav mettet'), findsOneWidget);
    });
  });
}
