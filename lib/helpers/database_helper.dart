import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('aqi_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE aqi_data (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      city TEXT NOT NULL,
      aqi INTEGER NOT NULL,
      timestamp TEXT NOT NULL
    )
    ''');
  }

  /// Save a new reading
  Future<int> insertAQI(String city, int aqi) async {
    final db = await instance.database;
    return await db.insert('aqi_data', {
      'city': city,
      'aqi': aqi,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get history for the chart
  Future<List<Map<String, dynamic>>> getHistoryForCity(String city) async {
    final db = await instance.database;
    return await db.query(
      'aqi_data',
      where: 'city = ?',
      whereArgs: [city],
      orderBy: 'timestamp ASC',
    );
  }
}