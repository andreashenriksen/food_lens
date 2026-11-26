import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

/// Opens and migrates the local SQLite database.
///
/// Everything the user logs lives here, on the device — the Kassalapp API is
/// only ever read from.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  static const int _schemaVersion = 1;

  /// Selects the SQLite implementation for the current platform.
  ///
  /// Android and iOS use the native plugin; desktop uses FFI; web uses a
  /// WebAssembly build backed by IndexedDB. Platform detection goes through
  /// [kIsWeb] and [defaultTargetPlatform] rather than `dart:io`, because
  /// `dart:io`'s `Platform` compiles on web but throws the moment it is read.
  static void initPlatform() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        // The bundled sqflite plugin already provides the default factory.
        break;
    }
  }

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    // The web factory ignores the directory and keys on the name alone.
    final path = kIsWeb
        ? 'food_lens.db'
        : p.join(await getDatabasesPath(), 'food_lens.db');

    return openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day TEXT NOT NULL,
            meal TEXT NOT NULL,
            status TEXT NOT NULL,
            name TEXT NOT NULL,
            brand TEXT,
            ean TEXT,
            amount REAL NOT NULL,
            unit TEXT NOT NULL,
            nutrients TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        // Every read is "give me one day", so the day column carries the index.
        await db.execute('CREATE INDEX idx_entries_day ON entries(day)');

        await db.execute('''
          CREATE TABLE recent_products (
            ean TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            brand TEXT,
            payload TEXT NOT NULL,
            used_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
