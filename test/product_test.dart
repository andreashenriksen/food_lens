import 'package:flutter_test/flutter_test.dart';
import 'package:food_lens/src/models/product.dart';

void main() {
  group('Product.fromJson', () {
    test('maps a Kassalapp product payload', () {
      final product = Product.fromJson({
        'id': 4242,
        'name': 'Havregryn Lettkokte 1kg',
        'brand': 'Axa',
        'vendor': 'Lantmännen Cerealia',
        'ean': '7311070363012',
        'image': 'https://example.test/havregryn.jpg',
        'current_price': 29.9,
        'weight': 1,
        'weight_unit': 'kg',
        'store': {'name': 'Kiwi'},
        'nutrition': [
          {
            'code': 'energi_kcal',
            'display_name': 'Energi',
            'amount': 370,
            'unit': 'kcal',
          },
          {
            'code': 'protein',
            'display_name': 'Protein',
            'amount': 13,
            'unit': 'g',
          },
        ],
        'allergens': [
          {'code': 'gluten', 'display_name': 'Gluten', 'contains': 'YES'},
          {'code': 'egg', 'display_name': 'Egg', 'contains': 'NO'},
          {
            'code': 'melk',
            'display_name': 'Melk',
            'contains': 'CAN_CONTAIN_TRACES',
          },
        ],
      });

      expect(product.name, 'Havregryn Lettkokte 1kg');
      expect(product.subtitle, 'Axa · Lantmännen Cerealia');
      expect(product.storeName, 'Kiwi');
      expect(product.packageSize, 1000); // 1 kg normalised to grams
      expect(product.basis, MeasureBasis.grams);
      expect(product.nutritionPer100.kcal, 370);
      expect(product.allergens.map((a) => a.presence), [
        AllergenPresence.yes,
        AllergenPresence.no,
        AllergenPresence.traces,
      ]);
    });

    test('treats litre-based products as millilitres', () {
      final product = Product.fromJson({
        'id': 1,
        'name': 'Lettmelk',
        'weight': 1.5,
        'weight_unit': 'l',
      });

      expect(product.basis, MeasureBasis.millilitres);
      expect(product.packageSize, 1500);
      expect(product.basis.unitLabel, 'ml');
    });

    test('has no package size for goods sold per piece', () {
      final product = Product.fromJson({
        'id': 2,
        'name': 'Agurk',
        'weight': 1,
        'weight_unit': 'stk',
      });

      expect(product.packageSize, isNull);
    });

    test('scales nutrients to a chosen portion', () {
      final product = Product.fromJson({
        'id': 3,
        'name': 'Yoghurt',
        'weight': 350,
        'weight_unit': 'g',
        'nutrition': [
          {
            'code': 'energi_kcal',
            'display_name': 'Energi',
            'amount': 80,
            'unit': 'kcal',
          },
        ],
      });

      expect(product.nutrientsFor(350).kcal, closeTo(280, 0.001));
      expect(product.nutrientsFor(50).kcal, closeTo(40, 0.001));
    });
  });

  test('mergedWith fills gaps from a richer variant', () {
    final withoutNutrition = Product.fromJson({
      'id': 10,
      'name': 'Brus',
      'current_price': 24.9,
      'store': {'name': 'Rema 1000'},
    });
    final withNutrition = Product.fromJson({
      'id': 11,
      'name': 'Brus',
      'weight': 500,
      'weight_unit': 'ml',
      'nutrition': [
        {
          'code': 'energi_kcal',
          'display_name': 'Energi',
          'amount': 42,
          'unit': 'kcal',
        },
      ],
    });

    final merged = withoutNutrition.mergedWith(withNutrition);

    // The price and store of the primary listing survive; the declaration is
    // borrowed from the variant that actually has one.
    expect(merged.currentPrice, 24.9);
    expect(merged.storeName, 'Rema 1000');
    expect(merged.nutritionPer100.kcal, 42);
    expect(merged.packageSize, 500);
    expect(merged.basis, MeasureBasis.millilitres);
  });

  test('storage round trip keeps what the product screen needs', () {
    final original = Product.fromJson({
      'id': 5,
      'name': 'Kyllingfilet',
      'brand': 'Prior',
      'ean': '7020097011234',
      'weight': 400,
      'weight_unit': 'g',
      'nutrition': [
        {
          'code': 'protein',
          'display_name': 'Protein',
          'amount': 23,
          'unit': 'g',
        },
      ],
    });

    final restored = Product.fromStorageMap(original.toStorageMap());

    expect(restored.name, 'Kyllingfilet');
    expect(restored.brand, 'Prior');
    expect(restored.ean, '7020097011234');
    expect(restored.packageSize, 400);
    expect(restored.nutritionPer100.protein, 23);
  });
}
