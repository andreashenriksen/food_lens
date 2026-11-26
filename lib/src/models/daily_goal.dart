/// The user's daily targets.
///
/// Macro targets are optional: many people only care about the calorie limit,
/// and the UI hides macro progress when these are null.
class DailyGoal {
  const DailyGoal({required this.kcal, this.proteinG, this.carbsG, this.fatG});

  final double kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  static const DailyGoal fallback = DailyGoal(kcal: 2000);

  bool get hasMacroTargets =>
      proteinG != null || carbsG != null || fatG != null;

  /// Derives gram targets from an energy split, e.g. 30/40/30.
  ///
  /// Protein and carbohydrate supply 4 kcal per gram, fat 9.
  factory DailyGoal.fromSplit({
    required double kcal,
    required double proteinPercent,
    required double carbsPercent,
    required double fatPercent,
  }) => DailyGoal(
    kcal: kcal,
    proteinG: kcal * proteinPercent / 100 / 4,
    carbsG: kcal * carbsPercent / 100 / 4,
    fatG: kcal * fatPercent / 100 / 9,
  );

  DailyGoal copyWith({
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    bool clearMacros = false,
  }) => DailyGoal(
    kcal: kcal ?? this.kcal,
    proteinG: clearMacros ? null : (proteinG ?? this.proteinG),
    carbsG: clearMacros ? null : (carbsG ?? this.carbsG),
    fatG: clearMacros ? null : (fatG ?? this.fatG),
  );
}

/// Biological sex as used by the Mifflin-St Jeor equation.
enum BodySex { female, male }

enum ActivityLevel {
  sedentary('Stillesittende', 1.2),
  light('Lett aktiv', 1.375),
  moderate('Moderat aktiv', 1.55),
  high('Veldig aktiv', 1.725),
  athlete('Ekstremt aktiv', 1.9);

  const ActivityLevel(this.label, this.factor);
  final String label;
  final double factor;
}

enum WeightGoal {
  lose('Gå ned i vekt', -500),
  maintain('Holde vekten', 0),
  gain('Gå opp i vekt', 300);

  const WeightGoal(this.label, this.kcalAdjustment);
  final String label;
  final double kcalAdjustment;
}

/// Suggests a daily calorie limit using the Mifflin-St Jeor equation.
///
/// This is an estimate to start from, not medical advice — the settings screen
/// says as much and the number stays editable.
double estimateDailyCalories({
  required BodySex sex,
  required int ageYears,
  required double weightKg,
  required double heightCm,
  required ActivityLevel activity,
  required WeightGoal goal,
}) {
  final bmr =
      10 * weightKg +
      6.25 * heightCm -
      5 * ageYears +
      (sex == BodySex.male ? 5 : -161);
  final maintenance = bmr * activity.factor;
  // Keep the suggestion above a floor rather than returning an unsafe deficit.
  return (maintenance + goal.kcalAdjustment).clamp(1200, 6000);
}
