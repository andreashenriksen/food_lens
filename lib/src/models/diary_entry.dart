import 'nutrients.dart';
import 'product.dart';

enum MealType {
  breakfast('Frokost'),
  lunch('Lunsj'),
  dinner('Middag'),
  snack('Snacks');

  const MealType(this.label);
  final String label;

  static MealType fromName(String name) =>
      MealType.values.firstWhere((m) => m.name == name, orElse: () => snack);
}

/// Whether a row is something the user intends to eat or has already eaten.
///
/// Planning and tracking share one table so a planned item can be ticked off
/// into an eaten one without losing its identity or being retyped.
enum EntryStatus { planned, eaten }

/// One logged or planned food item on a given day.
///
/// Nutrients are stored resolved rather than as a reference to a product, so
/// history stays correct even if a product's declaration later changes or the
/// product disappears from the API.
class DiaryEntry {
  const DiaryEntry({
    this.id,
    required this.date,
    required this.meal,
    required this.status,
    required this.name,
    this.brand,
    this.ean,
    required this.amount,
    required this.unit,
    required this.nutrients,
    required this.createdAt,
  });

  final int? id;

  /// The day this belongs to, normalised to midnight local time.
  final DateTime date;

  final MealType meal;
  final EntryStatus status;
  final String name;
  final String? brand;
  final String? ean;

  /// How much was eaten, in [unit].
  final double amount;

  /// `g`, `ml`, or `porsjon` for entries logged by serving.
  final String unit;

  /// Absolute nutrients for [amount] — already scaled, not per 100.
  final Nutrients nutrients;

  final DateTime createdAt;

  double get kcal => nutrients.kcal ?? 0;

  bool get isPlanned => status == EntryStatus.planned;

  /// Builds an entry from a product and a chosen portion size.
  factory DiaryEntry.fromProduct(
    Product product, {
    required DateTime date,
    required MealType meal,
    required EntryStatus status,
    required double amount,
  }) => DiaryEntry(
    date: DateUtilsX.dayOf(date),
    meal: meal,
    status: status,
    name: product.name,
    brand: product.brand,
    ean: product.ean,
    amount: amount,
    unit: product.basis.unitLabel,
    nutrients: product.nutrientsFor(amount),
    createdAt: DateTime.now(),
  );

  DiaryEntry copyWith({
    int? id,
    DateTime? date,
    MealType? meal,
    EntryStatus? status,
    String? name,
    double? amount,
    Nutrients? nutrients,
  }) => DiaryEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    meal: meal ?? this.meal,
    status: status ?? this.status,
    name: name ?? this.name,
    brand: brand,
    ean: ean,
    amount: amount ?? this.amount,
    unit: unit,
    nutrients: nutrients ?? this.nutrients,
    createdAt: createdAt,
  );

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'day': DateUtilsX.toKey(date),
    'meal': meal.name,
    'status': status.name,
    'name': name,
    'brand': brand,
    'ean': ean,
    'amount': amount,
    'unit': unit,
    'nutrients': nutrients.toJson(),
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory DiaryEntry.fromDbMap(Map<String, dynamic> map) => DiaryEntry(
    id: map['id'] as int?,
    date: DateUtilsX.fromKey(map['day'] as String),
    meal: MealType.fromName(map['meal'] as String),
    status: map['status'] == 'planned'
        ? EntryStatus.planned
        : EntryStatus.eaten,
    name: map['name'] as String,
    brand: map['brand'] as String?,
    ean: map['ean'] as String?,
    amount: (map['amount'] as num).toDouble(),
    unit: map['unit'] as String,
    nutrients: Nutrients.fromJson(map['nutrients'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );
}

/// Date helpers shared by the diary and the database key format.
class DateUtilsX {
  /// Strips the time component so a day is comparable and storable.
  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// `yyyy-MM-dd`, the sortable key used as the database's day column.
  static String toKey(DateTime value) {
    final d = dayOf(value);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime fromKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
