import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../models/horario_empleado.dart';

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
    final dbPath = kIsWeb ? filePath : join(await getDatabasesPath(), filePath);
    final db = await openDatabase(
      dbPath,
      version: 12, // v12 incluye horas_ordinarias y horas_ordinarias_min
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
    return db;
  }

  Future _createDB(Database db, int version) async {
    // empleados
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

    // empresas (AHORA con max_usuarios_activos, cuota, observaciones)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresas (
        cif_empresa TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        direccion TEXT,
        telefono TEXT,
        codigo_postal TEXT,
        email TEXT,
        basedatos TEXT,
        max_usuarios_activos INTEGER,
        cuota REAL,
        observaciones TEXT
      )
    ''');

    // sucursales
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

    // incidencias
    await db.execute('DROP TABLE IF EXISTS incidencias;');
    await db.execute('''
      CREATE TABLE incidencias (
        codigo TEXT PRIMARY KEY,
        descripcion TEXT,
        cif_empresa TEXT,
        computa INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // historico
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

    // horarios_empleado con nuevos campos
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
        margen_entrada_despues INTEGER NOT NULL DEFAULT 30,
        horas_ordinarias TEXT,
        horas_ordinarias_min INTEGER
      )
    ''');
  }

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
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE horarios_empleado ADD COLUMN margen_entrada_antes INTEGER NOT NULL DEFAULT 10');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE horarios_empleado ADD COLUMN margen_entrada_despues INTEGER NOT NULL DEFAULT 30');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE empleados ADD COLUMN id INTEGER');
        await db.execute('ALTER TABLE empleados ADD COLUMN pin_fichaje TEXT');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE historico ADD COLUMN uuid TEXT UNIQUE');
      } catch (_) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE empresas ADD COLUMN max_usuarios_activos INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE empresas ADD COLUMN cuota REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE empresas ADD COLUMN observaciones TEXT');
      } catch (_) {}
    }
    // v12: horarios_empleado obtiene horas_ordinarias y horas_ordinarias_min
    if (oldVersion < 12) {
      try { await db.execute('ALTER TABLE horarios_empleado ADD COLUMN horas_ordinarias TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE horarios_empleado ADD COLUMN horas_ordinarias_min INTEGER'); } catch (_) {}
    }
  }

  // ==================== HISTORICO ======================
  Future<int> insertHistorico(Historico h) async {
    final db = await database;
    final data = h.toDbMap();
    print('[DEBUG][DatabaseHelper.insertHistorico] Datos a insertar: $data');
    print('[DEBUG][DatabaseHelper.insertHistorico] incidencia_codigo específico: ${data['incidencia_codigo']}');
    return db.insert('historico', data);
  }

  Future<int> actualizarSincronizado(int id, bool sincronizado) async {
    final db = await database;
    return db.update(
      'historico',
      {'sincronizado': sincronizado ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Historico>> historicosPendientes() async {
    final db = await database;
    final maps = await db.query('historico', where: 'sincronizado = 0');
    return maps.map((m) => Historico.fromMap(m)).toList();
  }

  Future<int> borrarHistoricosPorEmpresa(String cifEmpresa) async {
    final db = await database;
    return db.delete('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
  }

  // ==================== INCIDENCIAS ======================
  Future<List<Incidencia>> cargarIncidenciasLocal(String cifEmpresa) async {
    final db = await database;
    final maps = await db.query('incidencias', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    return maps.map((m) => Incidencia.fromMap(m)).toList();
  }

  // ==================== HORARIOS EMPLEADO ======================
  Future<int> insertarHorarioEmpleado(HorarioEmpleado h) async {
    final db = await database;
    return db.insert('horarios_empleado', h.toMap());
  }

  Future<List<HorarioEmpleado>> cargarHorariosEmpleado(String dniEmpleado, String cifEmpresa) async {
    final db = await database;
    final maps = await db.query(
      'horarios_empleado',
      where: 'dni_empleado = ? AND cif_empresa = ?',
      whereArgs: [dniEmpleado, cifEmpresa],
    );
    return maps.map((m) => HorarioEmpleado.fromMap(m)).toList();
  }

  Future<List<HorarioEmpleado>> cargarHorariosEmpresa(String cifEmpresa) async {
    final db = await database;
    final maps = await db.query('horarios_empleado', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    return maps.map((m) => HorarioEmpleado.fromMap(m)).toList();
  }

  Future<int> actualizarHorarioEmpleado(HorarioEmpleado h) async {
    final db = await database;
    return db.update('horarios_empleado', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
  }

  Future<int> borrarHorarioEmpleado(int id) async {
    final db = await database;
    return db.delete('horarios_empleado', where: 'id = ?', whereArgs: [id]);
  }
}
