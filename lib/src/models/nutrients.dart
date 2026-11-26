import 'dart:convert';

/// Kilojoules per kilocalorie, used when a product only reports energy in kJ.
const double _kjPerKcal = 4.184;

/// A bundle of nutritional values.
///
/// The same class is used for two things: the *reference* values a product
/// declares (always per 100 g or 100 ml, which is what Kassalapp returns) and
/// the *absolute* values of something actually eaten. [scale] converts between
/// them. Every field is nullable because Norwegian products routinely declare
/// only a subset — a bottle of water lists energy and salt and nothing else.
class Nutrients {
  const Nutrients({
    this.kcal,
    this.protein,
    this.carbs,
    this.sugars,
    this.fat,
    this.saturatedFat,
    this.fiber,
    this.salt,
  });

  /// Energy in kilocalories.
  final double? kcal;

  /// Grams of protein.
  final double? protein;

  /// Grams of carbohydrate, including [sugars].
  final double? carbs;

  /// Grams of sugar, a subset of [carbs].
  final double? sugars;

  /// Grams of fat, including [saturatedFat].
  final double? fat;

  /// Grams of saturated fat, a subset of [fat].
  final double? saturatedFat;

  /// Grams of dietary fibre.
  final double? fiber;

  /// Grams of salt.
  final double? salt;

  static const Nutrients empty = Nutrients();

  bool get isEmpty =>
      kcal == null &&
      protein == null &&
      carbs == null &&
      fat == null &&
      sugars == null &&
      saturatedFat == null &&
      fiber == null &&
      salt == null;

  bool get hasEnergy => kcal != null;

  /// Multiplies every present value by [factor].
  ///
  /// To turn per-100 g reference values into what a 250 g portion contains,
  /// pass `250 / 100`.
  Nutrients scale(double factor) => Nutrients(
    kcal: _mul(kcal, factor),
    protein: _mul(protein, factor),
    carbs: _mul(carbs, factor),
    sugars: _mul(sugars, factor),
    fat: _mul(fat, factor),
    saturatedFat: _mul(saturatedFat, factor),
    fiber: _mul(fiber, factor),
    salt: _mul(salt, factor),
  );

  /// Adds two bundles. A null on either side is treated as "not declared"
  /// rather than zero, so a sum is null only when neither side declared it.
  Nutrients operator +(Nutrients other) => Nutrients(
    kcal: _add(kcal, other.kcal),
    protein: _add(protein, other.protein),
    carbs: _add(carbs, other.carbs),
    sugars: _add(sugars, other.sugars),
    fat: _add(fat, other.fat),
    saturatedFat: _add(saturatedFat, other.saturatedFat),
    fiber: _add(fiber, other.fiber),
    salt: _add(salt, other.salt),
  );

  static double? _mul(double? value, double factor) =>
      value == null ? null : value * factor;

  static double? _add(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a + b;
  }

  /// Sums an arbitrary number of bundles.
  static Nutrients sum(Iterable<Nutrients> parts) =>
      parts.fold(Nutrients.empty, (total, part) => total + part);

  /// Parses Kassalapp's `nutrition` array.
  ///
  /// Each element looks like
  /// `{"code": "energi_kcal", "display_name": "Energi", "amount": 271, "unit": "kcal"}`.
  /// Codes are matched against known aliases and, failing that, against the
  /// Norwegian display name, because the code vocabulary is not formally
  /// documented and has grown over time.
  factory Nutrients.fromKassalList(List<dynamic>? entries) {
    if (entries == null || entries.isEmpty) return Nutrients.empty;

    double? kcal;
    double? kj;
    double? protein;
    double? carbs;
    double? sugars;
    double? fat;
    double? saturatedFat;
    double? fiber;
    double? salt;

    for (final raw in entries) {
      if (raw is! Map) continue;
      final amount = _toDouble(raw['amount']);
      if (amount == null) continue;

      final code = (raw['code'] ?? '').toString().toLowerCase();
      final name = (raw['display_name'] ?? '').toString().toLowerCase();
      final unit = (raw['unit'] ?? '').toString().toLowerCase();
      final key = '$code $name';

      // Mono- and polyunsaturated fats are not tracked, and they have to be
      // discarded up front: "enumettede"/"flerumettede" (and English
      // "unsaturated") all contain the substring used to spot saturated fat,
      // so they would otherwise be counted as it.
      if (_matches(key, const ['umettet', 'umettede', 'unsaturated'])) {
        continue;
      }

      // Order matters: the "hvorav" (of which) sub-entries must be tested
      // before their parent, since "hvorav_sukkerarter" contains neither
      // "karbohydrater" nor a distinguishing prefix in every payload.
      if (_matches(key, const ['mettet', 'mettede', 'saturated'])) {
        saturatedFat ??= amount;
      } else if (_matches(key, const ['sukker', 'sugar'])) {
        sugars ??= amount;
      } else if (_matches(key, const ['kostfiber', 'fiber', 'fibre'])) {
        fiber ??= amount;
      } else if (_matches(key, const ['protein'])) {
        protein ??= amount;
      } else if (_matches(key, const ['karbohydrat', 'carbohydrate'])) {
        carbs ??= amount;
      } else if (_matches(key, const ['fett', 'fat'])) {
        fat ??= amount;
      } else if (_matches(key, const ['salt', 'natrium', 'sodium'])) {
        // Sodium is reported in grams too; convert to the salt equivalent.
        final isSodium = _matches(key, const ['natrium', 'sodium']);
        salt ??= isSodium ? amount * 2.5 : amount;
      } else if (_matches(key, const ['energi', 'energy'])) {
        if (unit.contains('kcal') || code.contains('kcal')) {
          kcal ??= amount;
        } else if (unit.contains('kj') || code.contains('kj')) {
          kj ??= amount;
        }
      }
    }

    return Nutrients(
      // Prefer the declared kcal; fall back to converting kJ.
      kcal: kcal ?? (kj != null ? kj / _kjPerKcal : null),
      protein: protein,
      carbs: carbs,
      sugars: sugars,
      fat: fat,
      saturatedFat: saturatedFat,
      fiber: fiber,
      salt: salt,
    );
  }

  static bool _matches(String haystack, List<String> needles) =>
      needles.any(haystack.contains);

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      // Norwegian payloads occasionally use a decimal comma.
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'sugars': sugars,
    'fat': fat,
    'saturatedFat': saturatedFat,
    'fiber': fiber,
    'salt': salt,
  };

  factory Nutrients.fromMap(Map<String, dynamic> map) => Nutrients(
    kcal: _toDouble(map['kcal']),
    protein: _toDouble(map['protein']),
    carbs: _toDouble(map['carbs']),
    sugars: _toDouble(map['sugars']),
    fat: _toDouble(map['fat']),
    saturatedFat: _toDouble(map['saturatedFat']),
    fiber: _toDouble(map['fiber']),
    salt: _toDouble(map['salt']),
  );

  String toJson() => jsonEncode(toMap());

  factory Nutrients.fromJson(String source) =>
      Nutrients.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() => 'Nutrients(${toMap()})';
}
