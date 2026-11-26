import 'package:flutter/foundation.dart';

import '../data/diary_repository.dart';

import '../data/settings_repository.dart';
import '../models/daily_goal.dart';
import '../models/day_summary.dart';
import '../models/diary_entry.dart';
import '../models/product.dart';

/// Owns the currently viewed day, the goal, and that day's entries.
///
/// The Today and Plan screens are two views of the same state, so both read
/// from this one controller and stay in sync when either one writes.
class DiaryController extends ChangeNotifier {
  DiaryController(this._diary, this._settings);

  final DiaryRepository _diary;
  final SettingsRepository _settings;

  DateTime _selectedDay = DateUtilsX.dayOf(DateTime.now());
  DailyGoal _goal = DailyGoal.fallback;
  List<DiaryEntry> _entries = const [];
  List<Product> _recentProducts = const [];
  bool _loading = true;
  Object? _error;

  DateTime get selectedDay => _selectedDay;
  DailyGoal get goal => _goal;
  bool get isLoading => _loading;
  List<Product> get recentProducts => _recentProducts;

  /// Set when loading the diary failed — most often the local database being
  /// unavailable on the current platform. Surfaced by the screens so a failure
  /// reads as an error rather than an endless spinner.
  Object? get error => _error;

  bool get isToday =>
      DateUtilsX.toKey(_selectedDay) == DateUtilsX.toKey(DateTime.now());

  DaySummary get summary =>
      DaySummary(date: _selectedDay, entries: _entries, goal: _goal);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _goal = await _settings.loadGoal();
    } on Object catch (e) {
      // A missing preference store is not fatal; fall back to the default
      // goal so the diary is still usable.
      _goal = DailyGoal.fallback;
      debugPrint('Kunne ikke lese lagret mål: $e');
    }
    await _refresh();
  }

  /// Reloads the current day.
  ///
  /// Callers are fire-and-forget, so failures are captured into [error]
  /// rather than escaping into the void as an unhandled async error.
  Future<void> _refresh() async {
    try {
      _entries = await _diary.entriesForDay(_selectedDay);
      _recentProducts = await _diary.recentProducts();
      _error = null;
    } on Object catch (e) {
      _error = e;
      _entries = const [];
      _recentProducts = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Retries after a failed load.
  Future<void> retry() => load();

  Future<void> selectDay(DateTime day) async {
    final normalised = DateUtilsX.dayOf(day);
    if (DateUtilsX.toKey(normalised) == DateUtilsX.toKey(_selectedDay)) return;
    _selectedDay = normalised;
    _loading = true;
    notifyListeners();
    await _refresh();
  }

  Future<void> shiftDay(int days) =>
      selectDay(_selectedDay.add(Duration(days: days)));

  Future<void> setGoal(DailyGoal goal) async {
    _goal = goal;
    await _settings.saveGoal(goal);
    notifyListeners();
  }

  /// Logs a product portion against the selected day.
  Future<void> logProduct(
    Product product, {
    required MealType meal,
    required double amount,
    EntryStatus status = EntryStatus.eaten,
  }) async {
    await _diary.add(
      DiaryEntry.fromProduct(
        product,
        date: _selectedDay,
        meal: meal,
        status: status,
        amount: amount,
      ),
    );
    await _diary.rememberProduct(product);
    await _refresh();
  }

  /// Logs a manually entered item — for home cooking and anything the API
  /// does not carry.
  Future<void> logCustom(DiaryEntry entry) async {
    await _diary.add(entry.copyWith(date: _selectedDay));
    await _refresh();
  }

  Future<void> markEaten(DiaryEntry entry) async {
    if (entry.id == null) return;
    await _diary.setStatus(entry.id!, EntryStatus.eaten);
    await _refresh();
  }

  Future<void> markPlanned(DiaryEntry entry) async {
    if (entry.id == null) return;
    await _diary.setStatus(entry.id!, EntryStatus.planned);
    await _refresh();
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    await _diary.update(entry);
    await _refresh();
  }

  Future<void> deleteEntry(DiaryEntry entry) async {
    if (entry.id == null) return;
    await _diary.delete(entry.id!);
    await _refresh();
  }

  /// Re-adds a deleted entry, backing the undo action on the delete snackbar.
  Future<void> restoreEntry(DiaryEntry entry) async {
    await _diary.add(entry.copyWith(id: null));
    await _refresh();
  }

  /// Copies another day's items into the selected day as a plan.
  Future<int> copyDayInto(DateTime source) async {
    final count = await _diary.copyDay(source, _selectedDay);
    await _refresh();
    return count;
  }

  /// Marks every planned item for the day as eaten.
  Future<void> completeWholePlan() async {
    for (final entry in summary.plannedEntries) {
      if (entry.id != null) {
        await _diary.setStatus(entry.id!, EntryStatus.eaten);
      }
    }
    await _refresh();
  }

  Future<Map<String, double>> kcalHistory({int days = 14}) =>
      _diary.kcalByDay(days: days);
}
