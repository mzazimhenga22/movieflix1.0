import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';
import 'marketplace_item_model.dart';
import 'fan_events_screen.dart';

class MarketplaceItemDb {
  MarketplaceItemDb._();
  static final MarketplaceItemDb instance = MarketplaceItemDb._();

  // --- SQLite (mobile/desktop) ---
  sql.Database? _sqlDb;
  Future<sql.Database> get _databaseSql async {
    if (_sqlDb != null) return _sqlDb!;
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'marketplace.db');
    _sqlDb = await sql.openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            movieId INTEGER,
            movieTitle TEXT,
            moviePoster TEXT,
            location TEXT,
            price REAL,
            date TEXT,
            seats INTEGER,
            imageBase64 TEXT,
            seatDetails TEXT,
            ticketFileBase64 TEXT,
            isLocked INTEGER NOT NULL DEFAULT 0,
            sellerName TEXT,
            sellerEmail TEXT,
            isHidden INTEGER NOT NULL DEFAULT 0,
            name TEXT,
            description TEXT,
            startingPrice REAL,
            endDate TEXT,
            authenticityDocBase64 TEXT,
            pricePerDay REAL,
            minDays INTEGER,
            fundingGoal REAL,
            videoBase64 TEXT,
            synopsis TEXT,
            creatorName TEXT,
            creatorEmail TEXT,
            organizerName TEXT,
            organizerEmail TEXT,
            maxAttendees INTEGER
          )
        ''');
        debugPrint('SQLite table created at $path');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE items ADD COLUMN sellerName TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN sellerEmail TEXT');
          await db.execute(
              'ALTER TABLE items ADD COLUMN isHidden INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE items ADD COLUMN trailerUrl TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE items ADD COLUMN videoBase64 TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN synopsis TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN creatorName TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN creatorEmail TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN organizerName TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN organizerEmail TEXT');
          await db.execute(
              'UPDATE items SET videoBase64 = trailerUrl WHERE type = "indie_film"');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE items ADD COLUMN maxAttendees INTEGER');
        }
        debugPrint(
            'SQLite database upgraded from version $oldVersion to $newVersion');
      },
    );
    debugPrint('SQLite database opened at $path');
    return _sqlDb!;
  }

  // --- Sembast (Web & IO) ---
  Database? _sembastDb;
  final StoreRef<int, Map<String, dynamic>> _store =
      intMapStoreFactory.store('items');

  Future<Database> get _databaseSembast async {
    if (_sembastDb != null) return _sembastDb!;
    final dbPath = kIsWeb
        ? 'marketplace_sembast.db'
        : join(
            (await getApplicationDocumentsDirectory()).path,
            'marketplace_sembast.db',
          );
    final factory = kIsWeb ? databaseFactoryWeb : databaseFactoryIo;
    _sembastDb = await factory.openDatabase(dbPath);
    debugPrint('Sembast database opened at $dbPath');
    return _sembastDb!;
  }

  /// Insert a new item. Returns the item with its new `id`.
  Future<MarketplaceItem> insert(MarketplaceItem item) async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        final key = await _store.add(db, item.toSqlMap());
        debugPrint('Inserted item to Sembast with key: $key');
        return item.copyWith(updates: {'id': key});
      } else {
        final db = await _databaseSql;
        final id = await db.insert('items', item.toSqlMap());
        debugPrint('Inserted item to SQLite with id: $id');
        return item.copyWith(updates: {'id': id});
      }
    } catch (e) {
      debugPrint('Insertion error: $e');
      rethrow;
    }
  }

  /// Insert a fan event
  Future<void> insertFanEvent(FanEvent event) async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        final key = await _store.add(db, event.toSqlMap());
        debugPrint('Inserted fan event to Sembast with key: $key');
      } else {
        final db = await _databaseSql;
        await db.insert('items', event.toSqlMap());
        debugPrint('Inserted fan event to SQLite');
      }
    } catch (e) {
      debugPrint('Fan event insertion error: $e');
      rethrow;
    }
  }

  /// Update a fan event
  Future<void> updateFanEvent(FanEvent event) async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        await _store.record(int.parse(event.id!)).put(db, event.toSqlMap());
        debugPrint('Updated fan event in Sembast with key: ${event.id}');
      } else {
        final db = await _databaseSql;
        await db.update(
          'items',
          event.toSqlMap(),
          where: 'id = ?',
          whereArgs: [event.id],
        );
        debugPrint('Updated fan event in SQLite with id: ${event.id}');
      }
    } catch (e) {
      debugPrint('Fan event update error: $e');
      rethrow;
    }
  }

  /// Read all items, newest first.
  Future<List<MarketplaceItem>> getAll() async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        final records = await _store.find(
          db,
          finder: Finder(sortOrders: [SortOrder(Field.key, false)]),
        );
        debugPrint('Fetched ${records.length} items from Sembast');
        return records.map((r) => fromSql({...r.value, 'id': r.key})).toList();
      } else {
        final db = await _databaseSql;
        final rows = await db.query('items', orderBy: 'id DESC');
        debugPrint('Fetched ${rows.length} items from SQLite');
        return rows.map((r) => fromSql(r)).toList();
      }
    } catch (e) {
      debugPrint('Retrieval error: $e');
      rethrow;
    }
  }

  /// Read items by type, newest first.
  Future<List<MarketplaceItem>> getByType(String type) async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        final records = await _store.find(
          db,
          finder: Finder(
            filter: Filter.equals('type', type),
            sortOrders: [SortOrder(Field.key, false)],
          ),
        );
        debugPrint('Fetched ${records.length} $type items from Sembast');
        return records.map((r) => fromSql({...r.value, 'id': r.key})).toList();
      } else {
        final db = await _databaseSql;
        final rows = await db.query(
          'items',
          where: 'type = ?',
          whereArgs: [type],
          orderBy: 'id DESC',
        );
        debugPrint('Fetched ${rows.length} $type items from SQLite');
        return rows.map((r) => fromSql(r)).toList();
      }
    } catch (e) {
      debugPrint('Retrieval error for type $type: $e');
      rethrow;
    }
  }

  /// Read items by sellerEmail, newest first.
  Future<List<MarketplaceItem>> getBySeller(String sellerEmail) async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        final records = await _store.find(
          db,
          finder: Finder(
            filter: Filter.equals('sellerEmail', sellerEmail),
            sortOrders: [SortOrder(Field.key, false)],
          ),
        );
        debugPrint(
            'Fetched ${records.length} items for $sellerEmail from Sembast');
        return records.map((r) => fromSql({...r.value, 'id': r.key})).toList();
      } else {
        final db = await _databaseSql;
        final rows = await db.query(
          'items',
          where: 'sellerEmail = ?',
          whereArgs: [sellerEmail],
          orderBy: 'id DESC',
        );
        debugPrint('Fetched ${rows.length} items for $sellerEmail from SQLite');
        return rows.map((r) => fromSql(r)).toList();
      }
    } catch (e) {
      debugPrint('Retrieval error for seller $sellerEmail: $e');
      rethrow;
    }
  }

  /// Update an existing item.
  Future<MarketplaceItem> update(MarketplaceItem item) async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        await _store.record(item.id!).put(db, item.toSqlMap());
        debugPrint('Updated item in Sembast with key: ${item.id}');
        return item;
      } else {
        final db = await _databaseSql;
        await db.update(
          'items',
          item.toSqlMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
        debugPrint('Updated item in SQLite with id: ${item.id}');
        return item;
      }
    } catch (e) {
      debugPrint('Update error: $e');
      rethrow;
    }
  }

  /// Delete an item by its ID.
  Future<void> delete(int id) async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        await _store.record(id).delete(db);
        debugPrint('Deleted item from Sembast with key: $id');
      } else {
        final db = await _databaseSql;
        await db.delete('items', where: 'id = ?', whereArgs: [id]);
        debugPrint('Deleted item from SQLite with id: $id');
      }
    } catch (e) {
      debugPrint('Deletion error: $e');
      rethrow;
    }
  }

  /// Clear the entire database (for debugging).
  Future<void> clearDatabase() async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        await _store.delete(db);
        debugPrint('Cleared Sembast database');
      } else {
        final db = await _databaseSql;
        await db.delete('items');
        debugPrint('Cleared SQLite database');
      }
    } catch (e) {
      debugPrint('Clear database error: $e');
      rethrow;
    }
  }

  /// Read all fan events, newest first.
  Future<List<FanEvent>> getFanEvents() async {
    try {
      if (kIsWeb) {
        final db = await _databaseSembast;
        final records = await _store.find(
          db,
          finder: Finder(
            filter: Filter.equals('type', 'fan_event'),
            sortOrders: [SortOrder(Field.key, false)],
          ),
        );
        debugPrint('Fetched ${records.length} fan events from Sembast');
        return records
            .map((r) => FanEvent.fromSql({...r.value, 'id': r.key.toString()}))
            .toList();
      } else {
        final db = await _databaseSql;
        final rows = await db.query(
          'items',
          where: 'type = ?',
          whereArgs: ['fan_event'],
          orderBy: 'id DESC',
        );
        debugPrint('Fetched ${rows.length} fan events from SQLite');
        return rows.map((r) => FanEvent.fromSql(r)).toList();
      }
    } catch (e) {
      debugPrint('Fan events retrieval error: $e');
      rethrow;
    }
  }
}
