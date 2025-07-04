import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fichador.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print('[DEBUG][DatabaseHelper] Ruta real de la BD: $path');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
    print('[DEBUG][DatabaseHelper] Base de datos abierta/cargada');
    return db;
  }

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

    // Tabla de incidencias: limpia, como TEXT PRIMARY KEY
    await db.execute('DROP TABLE IF EXISTS incidencias;');
    await db.execute('''
      CREATE TABLE incidencias (
        codigo TEXT PRIMARY KEY,
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
        incidencia_codigo TEXT,
        observaciones TEXT,
        nombre_empleado TEXT,
        dni_empleado TEXT,
        id_sucursal TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');

    print('[DEBUG][DatabaseHelper] Tablas creadas (si no existían).');
  }

  // -- Insertar fichaje histórico --
  Future<int> insertHistorico(Historico h) async {
    final db = await database;
    final row = h.toDbMap();
    print('[DEBUG][DatabaseHelper.insertHistorico] Insertando fila: $row');
    final id = await db.insert('historico', row);
    print('[DEBUG][DatabaseHelper.insertHistorico] Nuevo ID insertado: $id');
    return id;
  }

  // -- Actualizar sincronización --
  Future<int> actualizarSincronizado(int id, bool sincronizado) async {
    final db = await database;
    return db.update(
      'historico',
      {'sincronizado': sincronizado ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -- Históricos pendientes --
  Future<List<Historico>> historicosPendientes() async {
    final db = await database;
    final maps = await db.query('historico', where: 'sincronizado = 0');
    return maps.map((m) => Historico.fromMap(m)).toList();
  }

  // -- Cargar incidencias locales por empresa --
  Future<List<Incidencia>> cargarIncidenciasLocal(String cifEmpresa) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'incidencias',
      where: 'cif_empresa = ?',
      whereArgs: [cifEmpresa],
    );
    return maps.map((m) => Incidencia.fromMap(m)).toList();
  }
}
