import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';

// Clase singleton para manejar la base de datos local SQLite
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init(); // Instancia única (singleton)
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
      version: 5,  // Actualizado a versión 5 para migraciones nuevas
      onCreate: _createDB, // Llama a la función para crear las tablas
      onUpgrade: _onUpgrade, // Para migraciones de esquema
    );
    print('[DEBUG][DatabaseHelper] Base de datos abierta/cargada');
    return db;
  }

  // Crea la estructura de tablas si no existen
  Future _createDB(Database db, int version) async {
    print('[DEBUG][DatabaseHelper] Creando estructura de tablas...');

    // Tabla de empleados con columnas puede_localizar y activo
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
        puede_localizar INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
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

    // Tabla de incidencias con columna computa
    await db.execute('DROP TABLE IF EXISTS incidencias;');
    await db.execute('''
      CREATE TABLE incidencias (
        codigo TEXT PRIMARY KEY,
        descripcion TEXT,
        cif_empresa TEXT,
        computa INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de histórico de fichajes con latitud y longitud
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
        sincronizado INTEGER NOT NULL DEFAULT 0,
        latitud REAL,
        longitud REAL
      )
    ''');

    print('[DEBUG][DatabaseHelper] Tablas creadas (si no existían).');
  }

  // Migraciones para versiones antiguas
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      print('[DEBUG][DatabaseHelper] Migrando DB a versión 2: añadiendo columnas latitud y longitud');
      try {
        await db.execute('ALTER TABLE historico ADD COLUMN latitud REAL');
      } catch (e) {
        print('[DEBUG][DatabaseHelper] La columna latitud ya existe o error: $e');
      }
      try {
        await db.execute('ALTER TABLE historico ADD COLUMN longitud REAL');
      } catch (e) {
        print('[DEBUG][DatabaseHelper] La columna longitud ya existe o error: $e');
      }
    }
    if (oldVersion < 3) {
      print('[DEBUG][DatabaseHelper] Migrando DB a versión 3: añadiendo columna computa en incidencias');
      try {
        await db.execute('ALTER TABLE incidencias ADD COLUMN computa INTEGER NOT NULL DEFAULT 1');
      } catch (e) {
        print('[DEBUG][DatabaseHelper] La columna computa ya existe o error: $e');
      }
    }
    if (oldVersion < 4) {
      print('[DEBUG][DatabaseHelper] Migrando DB a versión 4: añadiendo columna puede_localizar en empleados');
      try {
        await db.execute('ALTER TABLE empleados ADD COLUMN puede_localizar INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print('[DEBUG][DatabaseHelper] La columna puede_localizar ya existe o error: $e');
      }
    }
    if (oldVersion < 5) {
      print('[DEBUG][DatabaseHelper] Migrando DB a versión 5: añadiendo columna activo en empleados');
      try {
        await db.execute('ALTER TABLE empleados ADD COLUMN activo INTEGER NOT NULL DEFAULT 1');
      } catch (e) {
        print('[DEBUG][DatabaseHelper] La columna activo ya existe o error: $e');
      }
    }
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

  // -- Históricos pendientes (sincronizados = 0) --
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

  // -- Borrar todos los historicos de una empresa --
  Future<int> borrarHistoricosPorEmpresa(String cifEmpresa) async {
    final db = await database;
    return await db.delete('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
  }
}
