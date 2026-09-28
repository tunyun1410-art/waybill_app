import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('waybills.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE waybills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tracking_number TEXT,
        customer_phone TEXT,
        cod_amount REAL,
        courier_name TEXT,
        created_at TEXT
      )
    ''');
  }

  Future<int> insertWaybill(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('waybills', row);
  }

  Future<List<Map<String, dynamic>>> getWaybills() async {
    final db = await instance.database;
    return await db.query('waybills', orderBy: 'id DESC');
  }
}
