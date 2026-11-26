import 'package:flutter_test/flutter_test.dart';
import 'package:food_lens/src/models/nutrients.dart';

void main() {
  group('Nutrients.fromKassalList', () {
    test('reads a full Norwegian declaration', () {
      final nutrients = Nutrients.fromKassalList([
        {
          'code': 'energi_kj',
          'display_name': 'Energi',
          'amount': 1130,
          'unit': 'kj',
        },
        {
          'code': 'energi_kcal',
          'display_name': 'Energi',
          'amount': 271,
          'unit': 'kcal',
        },
        {
          'code': 'fett_totalt',
          'display_name': 'Fett',
          'amount': 12.5,
          'unit': 'g',
        },
        {
          'code': 'hvorav_mettede_fettsyrer',
          'display_name': 'hvorav mettede fettsyrer',
          'amount': 7.2,
          'unit': 'g',
        },
        {
          'code': 'karbohydrater',
          'display_name': 'Karbohydrater',
          'amount': 30.1,
          'unit': 'g',
        },
        {
          'code': 'hvorav_sukkerarter',
          'display_name': 'hvorav sukkerarter',
          'amount': 2.4,
          'unit': 'g',
        },
        {
          'code': 'kostfiber',
          'display_name': 'Kostfiber',
          'amount': 3.0,
          'unit': 'g',
        },
        {
          'code': 'protein',
          'display_name': 'Protein',
          'amount': 8.8,
          'unit': 'g',
        },
        {'code': 'salt', 'display_name': 'Salt', 'amount': 1.1, 'unit': 'g'},
      ]);

      // The declared kcal wins over the kJ value.
      expect(nutrients.kcal, 271);
      expect(nutrients.fat, 12.5);
      expect(nutrients.saturatedFat, 7.2);
      expect(nutrients.carbs, 30.1);
      expect(nutrients.sugars, 2.4);
      expect(nutrients.fiber, 3.0);
      expect(nutrients.protein, 8.8);
      expect(nutrients.salt, 1.1);
    });

    test('derives kcal from kJ when only kJ is declared', () {
      final nutrients = Nutrients.fromKassalList([
        {
          'code': 'energi_kj',
          'display_name': 'Energi',
          'amount': 418.4,
          'unit': 'kj',
        },
      ]);

      expect(nutrients.kcal, closeTo(100, 0.01));
    });

    test('does not mistake saturated fat for total fat', () {
      final nutrients = Nutrients.fromKassalList([
        {
          'code': 'hvorav_mettede_fettsyrer',
          'display_name': 'hvorav mettede fettsyrer',
          'amount': 2.0,
          'unit': 'g',
        },
        {
          'code': 'fett_totalt',
          'display_name': 'Fett',
          'amount': 9.0,
          'unit': 'g',
        },
      ]);

      expect(nutrients.fat, 9.0);
      expect(nutrients.saturatedFat, 2.0);
    });

    test('ignores mono- and polyunsaturated fat entries', () {
      // "enumettede"/"flerumettede" contain the substring used to detect
      // saturated fat, so they must not leak into it.
      final nutrients = Nutrients.fromKassalList([
        {
          'code': 'fett_totalt',
          'display_name': 'Fett',
          'amount': 20.0,
          'unit': 'g',
        },
        {
          'code': 'hvorav_enumettede_fettsyrer',
          'display_name': 'hvorav enumettede fettsyrer',
          'amount': 11.0,
          'unit': 'g',
        },
        {
          'code': 'hvorav_flerumettede_fettsyrer',
          'display_name': 'hvorav flerumettede fettsyrer',
          'amount': 6.0,
          'unit': 'g',
        },
        {
          'code': 'hvorav_mettede_fettsyrer',
          'display_name': 'hvorav mettede fettsyrer',
          'amount': 3.0,
          'unit': 'g',
        },
      ]);

      expect(nutrients.fat, 20.0);
      expect(nutrients.saturatedFat, 3.0);
    });

    test('converts declared sodium into a salt equivalent', () {
      final nutrients = Nutrients.fromKassalList([
        {
          'code': 'natrium',
          'display_name': 'Natrium',
          'amount': 0.4,
          'unit': 'g',
        },
      ]);

      expect(nutrients.salt, closeTo(1.0, 0.001));
    });

    test('accepts decimal commas and string amounts', () {
      final nutrients = Nutrients.fromKassalList([
        {
          'code': 'protein',
          'display_name': 'Protein',
          'amount': '12,5',
          'unit': 'g',
        },
      ]);

      expect(nutrients.protein, 12.5);
    });

    test('returns empty for a missing or empty declaration', () {
      expect(Nutrients.fromKassalList(null).isEmpty, isTrue);
      expect(Nutrients.fromKassalList([]).isEmpty, isTrue);
    });
  });

  group('arithmetic', () {
    const perHundred = Nutrients(kcal: 200, protein: 10, fat: 5);

    test('scale converts a per-100 basis into a portion', () {
      final portion = perHundred.scale(250 / 100);

      expect(portion.kcal, 500);
      expect(portion.protein, 25);
      expect(portion.fat, 12.5);
      // Undeclared values stay undeclared rather than becoming zero.
      expect(portion.carbs, isNull);
    });

    test('addition treats null as undeclared, not zero', () {
      const a = Nutrients(kcal: 100, protein: 5);
      const b = Nutrients(kcal: 50, carbs: 20);

      final total = a + b;

      expect(total.kcal, 150);
      expect(total.protein, 5);
      expect(total.carbs, 20);
      expect(total.fat, isNull);
    });

    test('sum folds an empty list into empty', () {
      expect(Nutrients.sum(const []).isEmpty, isTrue);
    });

    test('survives a JSON round trip', () {
      const original = Nutrients(kcal: 271.5, protein: 8.8, salt: 1.1);

      final restored = Nutrients.fromJson(original.toJson());

      expect(restored.kcal, 271.5);
      expect(restored.protein, 8.8);
      expect(restored.salt, 1.1);
      expect(restored.fat, isNull);
    });
  });
}
