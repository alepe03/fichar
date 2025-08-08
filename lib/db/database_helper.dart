import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../models/horario_empleado.dart';

/// Clase singleton para gestionar el acceso a la base de datos local SQLite
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Getter para obtener la instancia de la base de datos, la inicializa si es necesario
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fichador.db');
    return _database!;
  }

  /// Inicializa la base de datos, eligiendo la ruta según si es web o no
  Future<Database> _initDB(String filePath) async {
    final dbPath = kIsWeb ? filePath : join(await getDatabasesPath(), filePath);

    print('[DEBUG][DatabaseHelper] Ruta real de la BD: $dbPath');

    final db = await openDatabase(
      dbPath,
      version: 10, // <-- ¡IMPORTANTE! Ahora versión 10
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );

    print('[DEBUG][DatabaseHelper] Base de datos abierta/cargada');
    return db;
  }

  /// Crea las tablas necesarias en la base de datos si no existen
  Future _createDB(Database db, int version) async {
    print('[DEBUG][DatabaseHelper] Creando estructura de tablas...');

    // Tabla de empleados (ahora con id y pin_fichaje)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleados (
        usuario TEXT NOT NULL,
        cif_empresa TEXT NOT NULL,
        id INTEGER,
        pin_fichaje TEXT,
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

    // Tabla de incidencias (se borra y recrea por si hay cambios)
    await db.execute('DROP TABLE IF EXISTS incidencias;');
    await db.execute('''
      CREATE TABLE incidencias (
        codigo TEXT PRIMARY KEY,
        descripcion TEXT,
        cif_empresa TEXT,
        computa INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de registros históricos de fichajes (ahora con uuid)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historico (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE NOT NULL,
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

    // Tabla de horarios de empleados CON LOS DOS CAMPOS DE MARGEN
    await db.execute('''
      CREATE TABLE IF NOT EXISTS horarios_empleado (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni_empleado TEXT NOT NULL,
        cif_empresa TEXT NOT NULL,
        dia_semana INTEGER NOT NULL,
        hora_inicio TEXT NOT NULL,
        hora_fin TEXT NOT NULL,
        nombre_turno TEXT,
        margen_entrada_antes INTEGER NOT NULL DEFAULT 10,
        margen_entrada_despues INTEGER NOT NULL DEFAULT 30
      )
    ''');

    print('[DEBUG][DatabaseHelper] Tablas creadas (si no existían).');
  }

  /// Gestiona las migraciones de la base de datos entre versiones
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE historico ADD COLUMN latitud REAL');
      await db.execute('ALTER TABLE historico ADD COLUMN longitud REAL');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE incidencias ADD COLUMN computa INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE empleados ADD COLUMN puede_localizar INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE empleados ADD COLUMN activo INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS horarios_empleado (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dni_empleado TEXT NOT NULL,
          cif_empresa TEXT NOT NULL,
          dia_semana INTEGER NOT NULL,
          hora_inicio TEXT NOT NULL,
          hora_fin TEXT NOT NULL,
          nombre_turno TEXT
        )
      ''');
    }
    // MIGRACIÓN A V7: Añade la columna margen_entrada_antes si vienes de una versión anterior
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE horarios_empleado ADD COLUMN margen_entrada_antes INTEGER NOT NULL DEFAULT 10');
        print('[DEBUG][DatabaseHelper] Columna margen_entrada_antes añadida a horarios_empleado');
      } catch (e) {
        print('[DatabaseHelper][Upgrade] Error añadiendo columna margen_entrada_antes: $e');
      }
    }
    // MIGRACIÓN A V8: Añade la columna margen_entrada_despues si vienes de una versión anterior
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE horarios_empleado ADD COLUMN margen_entrada_despues INTEGER NOT NULL DEFAULT 30');
        print('[DEBUG][DatabaseHelper] Columna margen_entrada_despues añadida a horarios_empleado');
      } catch (e) {
        print('[DatabaseHelper][Upgrade] Error añadiendo columna margen_entrada_despues: $e');
      }
    }
    // MIGRACIÓN A V9: Añade columnas id y pin_fichaje a empleados si no existían
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE empleados ADD COLUMN id INTEGER;');
        await db.execute('ALTER TABLE empleados ADD COLUMN pin_fichaje TEXT;');
        print('[DEBUG][DatabaseHelper] Columnas id y pin_fichaje añadidas a empleados');
      } catch (e) {
        print('[DatabaseHelper][Upgrade] Error añadiendo columnas id/pin_fichaje: $e');
      }
    }
    // MIGRACIÓN A V10: Añade columna uuid a historico
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE historico ADD COLUMN uuid TEXT UNIQUE;');
        print('[DEBUG][DatabaseHelper] Columna uuid añadida a historico');
      } catch (e) {
        print('[DatabaseHelper][Upgrade] Error añadiendo columna uuid: $e');
      }
    }
  }

  // ==================== HISTORICO ======================
  /// Inserta un registro en la tabla historico
  Future<int> insertHistorico(Historico h) async {
    final db = await database;
    return await db.insert('historico', h.toDbMap());
  }

  /// Actualiza el estado de sincronización de un registro histórico
  Future<int> actualizarSincronizado(int id, bool sincronizado) async {
    final db = await database;
    return db.update(
      'historico',
      {'sincronizado': sincronizado ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Devuelve la lista de registros históricos pendientes de sincronizar
  Future<List<Historico>> historicosPendientes() async {
    final db = await database;
    final maps = await db.query('historico', where: 'sincronizado = 0');
    return maps.map((m) => Historico.fromMap(m)).toList();
  }

  /// Borra todos los registros históricos de una empresa concreta
  Future<int> borrarHistoricosPorEmpresa(String cifEmpresa) async {
    final db = await database;
    return await db.delete('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
  }

  // ==================== INCIDENCIAS ======================
  /// Carga las incidencias locales de una empresa concreta
  Future<List<Incidencia>> cargarIncidenciasLocal(String cifEmpresa) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'incidencias',
      where: 'cif_empresa = ?',
      whereArgs: [cifEmpresa],
    );
    return maps.map((m) => Incidencia.fromMap(m)).toList();
  }

  // ==================== HORARIOS EMPLEADO ======================
  /// Inserta un nuevo horario de empleado
  Future<int> insertarHorarioEmpleado(HorarioEmpleado h) async {
    final db = await database;
    return await db.insert('horarios_empleado', h.toMap());
  }

  /// Carga los horarios de un empleado concreto en una empresa
  Future<List<HorarioEmpleado>> cargarHorariosEmpleado(String dniEmpleado, String cifEmpresa) async {
    final db = await database;
    final maps = await db.query(
      'horarios_empleado',
      where: 'dni_empleado = ? AND cif_empresa = ?',
      whereArgs: [dniEmpleado, cifEmpresa],
    );
    return maps.map((m) => HorarioEmpleado.fromMap(m)).toList();
  }

  /// Carga todos los horarios de una empresa
  Future<List<HorarioEmpleado>> cargarHorariosEmpresa(String cifEmpresa) async {
    final db = await database;
    final maps = await db.query(
      'horarios_empleado',
      where: 'cif_empresa = ?',
      whereArgs: [cifEmpresa],
    );
    return maps.map((m) => HorarioEmpleado.fromMap(m)).toList();
  }

  /// Actualiza un horario de empleado existente
  Future<int> actualizarHorarioEmpleado(HorarioEmpleado h) async {
    final db = await database;
    return await db.update(
      'horarios_empleado',
      h.toMap(),
      where: 'id = ?',
      whereArgs: [h.id],
    );
  }

  /// Borra un horario de empleado por su ID
  Future<int> borrarHorarioEmpleado(int id) async {
    final db = await database;
    return await db.delete(
      'horarios_empleado',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
