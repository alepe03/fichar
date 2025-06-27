import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/historico.dart';

// Clase singleton para manejar la base de datos local SQLite
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init(); // Instancia única
  static Database? _database;

  DatabaseHelper._init();

  // Devuelve la base de datos, la crea si no existe
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fichador.db');
    return _database!;
  }

  // Inicializa la base de datos en la ruta indicada
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print('[DEBUG][DatabaseHelper] Ruta real de la BD: $path');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB, // Llama a la función para crear las tablas
    );
    print('[DEBUG][DatabaseHelper] Base de datos abierta/cargada');
    return db;
  }

  // Crea la estructura de tablas si no existen
  Future _createDB(Database db, int version) async {
    print('[DEBUG][DatabaseHelper] Creando estructura de tablas...');
    // Tabla de empleados
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleados (
        usuario TEXT NOT NULL,
        cif_empresa TEXT NOT NULL,
        direccion TEXT,
        poblacion TEXT,
        codigo_postal TEXT,
        telefono TEXT,
        email TEXT,
        nombre TEXT,
        dni TEXT,
        rol TEXT,
        password_hash TEXT,
        PRIMARY KEY (usuario, cif_empresa)
      )
    ''');

    // Tabla de empresas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresas (
        cif_empresa TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        direccion TEXT,
        telefono TEXT,
        codigo_postal TEXT,
        email TEXT,
        basedatos TEXT
      )
    ''');

    // Tabla de sucursales
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sucursales (
        cif_empresa TEXT NOT NULL,
        codigo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        direccion TEXT,
        horario TEXT,
        PRIMARY KEY (cif_empresa, codigo)
      )
    ''');

    // Tabla de incidencias
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incidencias (
        codigo INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion TEXT,
        cif_empresa TEXT
      )
    ''');

    // Tabla de histórico de fichajes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historico (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cif_empresa TEXT,
        usuario TEXT,
        fecha_entrada TEXT NOT NULL,
        fecha_salida TEXT,
        tipo TEXT,
        incidencia_codigo INTEGER,
        observaciones TEXT,
        nombre_empleado TEXT,
        dni_empleado TEXT,
        id_sucursal TEXT
      )
    ''');
    print('[DEBUG][DatabaseHelper] Tablas creadas (si no existían).');
  }

  /// Inserta un registro en 'historico', devuelve el ID local (autoincremental).
  /// Usa el mapa sin 'id' que genera `Historico.toDbMap()`.
  Future<int> insertHistorico(Historico h) async {
    final db = await database;
    final row = h.toDbMap();
    print('[DEBUG][DatabaseHelper.insertHistorico] Insertando fila: $row');
    final id = await db.insert('historico', row);
    print('[DEBUG][DatabaseHelper.insertHistorico] Nuevo ID insertado: $id');
    return id;
  }
}
