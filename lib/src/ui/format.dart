import 'package:intl/intl.dart';

import '../models/diary_entry.dart';

/// Number and date formatting for the Norwegian locale.
///
/// `nb_NO` gives a decimal comma and a non-breaking thousands separator, which
/// is what a Norwegian user expects to read on a nutrition label.
final NumberFormat _kcalFormat = NumberFormat('#,##0', 'nb_NO');
final NumberFormat _gramFormat = NumberFormat('0.#', 'nb_NO');
final NumberFormat _priceFormat = NumberFormat('#,##0.00', 'nb_NO');

String formatKcal(double? kcal) =>
    kcal == null ? '–' : _kcalFormat.format(kcal.round());

String formatGrams(double? grams) =>
    grams == null ? '–' : '${_gramFormat.format(grams)} g';

/// Formats an amount with its unit, dropping a pointless `.0`.
String formatAmount(double amount, String unit) =>
    '${_gramFormat.format(amount)} $unit';

String formatPrice(double? price) =>
    price == null ? '' : '${_priceFormat.format(price)} kr';

/// A day label that prefers "I dag" / "I går" / "I morgen" over a date.
String formatDayLabel(DateTime day) {
  final today = DateUtilsX.dayOf(DateTime.now());
  final target = DateUtilsX.dayOf(day);
  final diff = target.difference(today).inDays;

  return switch (diff) {
    0 => 'I dag',
    -1 => 'I går',
    1 => 'I morgen',
    _ => toBeginningOfSentenceCase(
      DateFormat('EEEE d. MMMM', 'nb_NO').format(target),
    ),
  };
}

String formatShortDate(DateTime day) =>
    DateFormat('d. MMM', 'nb_NO').format(day);
