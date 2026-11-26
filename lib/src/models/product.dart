import 'nutrients.dart';

/// Whether a product's declared values are per 100 g or per 100 ml.
enum MeasureBasis {
  grams,
  millilitres;

  String get unitLabel => this == MeasureBasis.grams ? 'g' : 'ml';
}

/// How confidently a product declares a given allergen.
enum AllergenPresence { no, yes, traces, unknown }

class Allergen {
  const Allergen({
    required this.code,
    required this.displayName,
    required this.presence,
  });

  final String code;
  final String displayName;
  final AllergenPresence presence;

  factory Allergen.fromJson(Map<String, dynamic> json) {
    final contains = (json['contains'] ?? '').toString().toUpperCase();
    return Allergen(
      code: (json['code'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['code'] ?? '').toString(),
      presence: switch (contains) {
        'YES' => AllergenPresence.yes,
        'NO' => AllergenPresence.no,
        'CAN_CONTAIN_TRACES' => AllergenPresence.traces,
        _ => AllergenPresence.unknown,
      },
    );
  }
}

/// A grocery product as returned by Kassalapp.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.brand,
    this.vendor,
    this.ean,
    this.imageUrl,
    this.storeName,
    this.currentPrice,
    this.packageSize,
    this.basis = MeasureBasis.grams,
    this.nutritionPer100 = Nutrients.empty,
    this.allergens = const [],
    this.ingredients,
  });

  final int id;
  final String name;
  final String? brand;
  final String? vendor;
  final String? ean;
  final String? imageUrl;
  final String? storeName;
  final double? currentPrice;

  /// Package size expressed in [basis] units (grams or millilitres), when the
  /// product declares a usable weight. Null for products sold per piece.
  final double? packageSize;

  final MeasureBasis basis;

  /// Declared values per 100 [basis] units.
  final Nutrients nutritionPer100;

  final List<Allergen> allergens;
  final String? ingredients;

  /// Brand and vendor collapsed into one subtitle line.
  String get subtitle {
    final parts = <String>[
      if (brand != null && brand!.isNotEmpty) brand!,
      if (vendor != null && vendor!.isNotEmpty && vendor != brand) vendor!,
    ];
    return parts.join(' · ');
  }

  bool get hasNutrition => !nutritionPer100.isEmpty;

  /// Nutrients contained in [amount] of this product, measured in [basis]
  /// units.
  Nutrients nutrientsFor(double amount) =>
      nutritionPer100.scale(amount / 100.0);

  factory Product.fromJson(Map<String, dynamic> json) {
    final store = json['store'];
    final weight = _toDouble(json['weight']);
    final weightUnit = (json['weight_unit'] ?? '').toString().toLowerCase();

    return Product(
      id: _toInt(json['id']) ?? 0,
      name: (json['name'] ?? 'Ukjent produkt').toString(),
      brand: _nonEmpty(json['brand']),
      vendor: _nonEmpty(json['vendor']),
      ean: _nonEmpty(json['ean']),
      imageUrl: _nonEmpty(json['image']),
      storeName: store is Map ? _nonEmpty(store['name']) : null,
      currentPrice: _toDouble(json['current_price']),
      packageSize: _packageSizeIn(weight, weightUnit),
      basis: _basisFor(weightUnit),
      nutritionPer100: Nutrients.fromKassalList(json['nutrition'] as List?),
      allergens: (json['allergens'] as List? ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Allergen.fromJson(e.cast<String, dynamic>()))
          .toList(),
      ingredients: _nonEmpty(json['ingredients']),
    );
  }

  /// Returns a copy with nutrition and allergens taken from [other] when this
  /// product is missing them.
  ///
  /// The EAN endpoint returns one entry per store, and only some of those
  /// carry the full declaration, so the richest entry is merged into the one
  /// shown.
  Product mergedWith(Product other) => Product(
    id: id,
    name: name,
    brand: brand ?? other.brand,
    vendor: vendor ?? other.vendor,
    ean: ean ?? other.ean,
    imageUrl: imageUrl ?? other.imageUrl,
    storeName: storeName,
    currentPrice: currentPrice,
    packageSize: packageSize ?? other.packageSize,
    basis: packageSize != null ? basis : other.basis,
    nutritionPer100: hasNutrition ? nutritionPer100 : other.nutritionPer100,
    allergens: allergens.isNotEmpty ? allergens : other.allergens,
    ingredients: ingredients ?? other.ingredients,
  );

  /// Converts a declared weight into grams or millilitres.
  ///
  /// Kassalapp also uses `weight_unit` values such as `stk` (pieces), which
  /// carry no mass information and therefore yield null.
  static double? _packageSizeIn(double? weight, String unit) {
    if (weight == null || weight <= 0) return null;
    return switch (unit) {
      'g' || 'ml' => weight,
      'kg' || 'l' => weight * 1000,
      'dl' => weight * 100,
      'cl' => weight * 10,
      _ => null,
    };
  }

  static MeasureBasis _basisFor(String unit) =>
      const {'ml', 'l', 'dl', 'cl'}.contains(unit)
      ? MeasureBasis.millilitres
      : MeasureBasis.grams;

  /// Compact form for the local "recently used" cache.
  ///
  /// Deliberately not the API payload: only what the product screen needs to
  /// render and log an item, so a cached hit works without a network call.
  Map<String, dynamic> toStorageMap() => {
    'id': id,
    'name': name,
    'brand': brand,
    'vendor': vendor,
    'ean': ean,
    'image': imageUrl,
    'packageSize': packageSize,
    'basis': basis.name,
    'nutrition': nutritionPer100.toMap(),
    'ingredients': ingredients,
  };

  factory Product.fromStorageMap(Map<String, dynamic> map) => Product(
    id: _toInt(map['id']) ?? 0,
    name: (map['name'] ?? '').toString(),
    brand: _nonEmpty(map['brand']),
    vendor: _nonEmpty(map['vendor']),
    ean: _nonEmpty(map['ean']),
    imageUrl: _nonEmpty(map['image']),
    packageSize: _toDouble(map['packageSize']),
    basis: map['basis'] == MeasureBasis.millilitres.name
        ? MeasureBasis.millilitres
        : MeasureBasis.grams,
    nutritionPer100: Nutrients.fromMap(
      (map['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    ingredients: _nonEmpty(map['ingredients']),
  );

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
