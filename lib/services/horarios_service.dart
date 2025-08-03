import 'package:http/http.dart' as http;
import '../models/horario_empleado.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import '../config.dart';
import 'package:flutter/foundation.dart';

// ----- CSV Parser -----
List<HorarioEmpleado> parseHorariosCsv(String csvBody) {
  final lines = csvBody.split('\n');
  if (lines.isNotEmpty) lines.removeAt(0); // Quitar cabecera CSV

  final List<HorarioEmpleado> horarios = [];
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      horarios.add(HorarioEmpleado.fromCsv(line));
    } catch (e) {
      print('Error parseando línea CSV: $line\nError: $e');
    }
  }
  return horarios;
}

class HorariosService {
  // ======= API: Descargar y guardar en SQLite POR EMPLEADO =======
  static Future<void> descargarYGuardarHorariosEmpleado({
    required String dniEmpleado,
    required String cifEmpresa,
    required String token,
    required String baseUrl,
  }) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    final url = Uri.parse('$baseUrl?Token=$token&Code=800&dni_empleado=$dniEmpleado&cif_empresa=$cifEmpresa');
    print('Descargando horarios desde: $url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      print('Respuesta del servidor (raw):');
      print(response.body);

      final List<HorarioEmpleado> horarios = await compute(parseHorariosCsv, response.body);

      print('Número de horarios parseados: ${horarios.length}');
      for (var h in horarios) {
        print('Horario parseado: $h');
      }

      final db = await DatabaseHelper.instance.database;

      print('Borrando horarios locales previos de $dniEmpleado');
      await db.delete('horarios_empleado', where: 'dni_empleado = ? AND cif_empresa = ?', whereArgs: [dniEmpleado, cifEmpresa]);

      for (var h in horarios) {
        print('Insertando horario en BD local: $h');
        await db.insert(
          'horarios_empleado',
          h.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Confirmar que quedan horarios en la BD tras insertar
      final mapas = await db.query('horarios_empleado', where: 'dni_empleado = ? AND cif_empresa = ?', whereArgs: [dniEmpleado, cifEmpresa]);
      print('Horarios en BD local después de insertar:');
      for (var m in mapas) {
        print(m);
      }

      print('Horarios guardados correctamente: ${horarios.length}');
    } else {
      throw Exception('Error descargando horarios: ${response.statusCode}');
    }
  }

  // ======= API: Descargar y guardar TODOS los horarios de la empresa =======
  static Future<void> descargarYGuardarHorariosEmpresa({
    required String cifEmpresa,
    required String token,
    required String baseUrl,
  }) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    // <-- AQUÍ EL CAMBIO: Code=800 y solo cif_empresa
    final url = Uri.parse('$baseUrl?Token=$token&Code=800&cif_empresa=$cifEmpresa');
    print('Descargando TODOS los horarios desde: $url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      print('Respuesta del servidor (raw):');
      print(response.body);

      final List<HorarioEmpleado> horarios = await compute(parseHorariosCsv, response.body);

      print('Número de horarios parseados: ${horarios.length}');
      final db = await DatabaseHelper.instance.database;

      // Borra TODOS los horarios locales de esa empresa antes de insertar los nuevos
      await db.delete('horarios_empleado', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);

      for (var h in horarios) {
        await db.insert(
          'horarios_empleado',
          h.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Confirma BD local tras insertar
      final mapas = await db.query('horarios_empleado', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
      print('Horarios en BD local después de insertar (todos):');
      for (var m in mapas) {
        print(m);
      }

      print('Horarios globales guardados correctamente: ${horarios.length}');
    } else {
      throw Exception('Error descargando horarios globales: ${response.statusCode}');
    }
  }

  // ======= Obtener local POR EMPLEADO =======
  static Future<List<HorarioEmpleado>> obtenerHorariosLocalPorEmpleado({
    required String dniEmpleado,
    required String cifEmpresa,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'horarios_empleado',
      where: 'dni_empleado = ? AND cif_empresa = ?',
      whereArgs: [dniEmpleado, cifEmpresa],
    );
    return maps.map((m) => HorarioEmpleado.fromMap(m)).toList();
  }

  // ======= Obtener TODOS los horarios de la empresa =======
  static Future<List<HorarioEmpleado>> obtenerHorariosLocalPorEmpresa({
    required String cifEmpresa,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'horarios_empleado',
      where: 'cif_empresa = ?',
      whereArgs: [cifEmpresa],
    );
    print('DEBUG: Query de todos los horarios para $cifEmpresa devuelve:');
    for (final m in maps) print(m);
    return maps.map((m) => HorarioEmpleado.fromMap(m)).toList();
  }

  // ======= Insertar Remoto =======
  static Future<bool> insertarHorarioRemoto({
    required HorarioEmpleado horario,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=801');

    final body = {
      'Token': token,
      'dni_empleado': horario.dniEmpleado,
      'cif_empresa': horario.cifEmpresa,
      'dia_semana': horario.diaSemana.toString(),
      'hora_inicio': horario.horaInicio,
      'hora_fin': horario.horaFin,
      'nombre_turno': horario.nombreTurno ?? '',
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    return response.statusCode == 200 && response.body.contains('OK');
  }

  // ======= Insertar Local =======
  static Future<int> insertarHorarioLocal(HorarioEmpleado horario) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('horarios_empleado', horario.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ======= Actualizar Remoto =======
  static Future<bool> actualizarHorarioRemoto({
    required HorarioEmpleado horario,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=802');
    final body = {
      'Token': token,
      'id': horario.id.toString(),
      'dni_empleado': horario.dniEmpleado,
      'cif_empresa': horario.cifEmpresa,
      'dia_semana': horario.diaSemana.toString(),
      'hora_inicio': horario.horaInicio,
      'hora_fin': horario.horaFin,
      'nombre_turno': horario.nombreTurno ?? '',
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    return response.statusCode == 200 && response.body.contains('OK');
  }

  // ======= Actualizar Local =======
  static Future<int> actualizarHorarioLocal(HorarioEmpleado horario) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'horarios_empleado',
      horario.toMap(),
      where: 'id = ?',
      whereArgs: [horario.id],
    );
  }

  // ======= Eliminar Remoto =======
  static Future<bool> eliminarHorarioRemoto({
    required int id,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=803');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'Token': token, 'id': id.toString()},
    );
    return response.statusCode == 200 && response.body.contains('OK');
  }

  // ======= Eliminar Local =======
  static Future<int> eliminarHorarioLocal(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('horarios_empleado', where: 'id = ?', whereArgs: [id]);
  }
}
