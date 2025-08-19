import 'package:http/http.dart' as http;              
import '../models/incidencia.dart';                     
import '../db/database_helper.dart';                     
import 'package:sqflite/sqflite.dart';                 
import '../config.dart';
import 'package:flutter/foundation.dart'; // Para compute

class IncidenciaService {
  // Función top-level para parsear CSV en otro isolate
  static List<Incidencia> parseIncidenciasCsv(String csvBody) {
    final lines = csvBody.split('\n');
    if (lines.isNotEmpty) lines.removeAt(0);

    final List<Incidencia> incidencias = [];
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        incidencias.add(Incidencia.fromCsv(line));
      } catch (e) {
        print('Error parseando línea CSV de incidencia: $line\nError: $e');
      }
    }
    return incidencias;
  }

  // Descarga y guarda incidencias desde la nube (API PHP)
  static Future<void> descargarYGuardarIncidencias(
      String cifEmpresa, String token, String baseUrl) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }
    final nombreBD = DatabaseConfig.databaseName;

    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=400&cif_empresa=$cifEmpresa');
    print('Descargando incidencias desde: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Parsear en isolate para no bloquear hilo UI
      final incidencias = await compute(parseIncidenciasCsv, response.body);

      final db = await DatabaseHelper.instance.database;
      await db.delete('incidencias', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
      for (var inc in incidencias) {
        await db.insert(
          'incidencias',
          inc.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      print('Incidencias guardadas correctamente: ${incidencias.length}');
    } else {
      throw Exception('Error descargando incidencias: ${response.statusCode}');
    }
  }

  // Carga las incidencias desde la base local SQLite
  static Future<List<Incidencia>> cargarIncidenciasLocal(String cifEmpresa) async {
    return await DatabaseHelper.instance.cargarIncidenciasLocal(cifEmpresa);
  }

  // ---------------------------
  //  Alta en la nube (API PHP)
  // ---------------------------
  static Future<String> insertarIncidenciaRemoto({
    required Incidencia incidencia,
    required String token,
  }) async {
    final nombreBD = DatabaseConfig.databaseName;
    final uri = Uri.parse('$BASE_URL?Code=401');

    final body = {
      'Token': token,
      'Bd': nombreBD,
      'codigo': incidencia.codigo,
      'descripcion': incidencia.descripcion ?? '',
      'cif_empresa': incidencia.cifEmpresa ?? '',
      'computa': incidencia.computa ? '1' : '0',  // Añadido
    };

    final response = await http.post(
      uri,
      body: body,
    );

    if (response.statusCode == 200) {
      if (response.body.startsWith("OK")) {
        return "OK";
      } else {
        return "Error al subir incidencia: ${response.body}";
      }
    } else {
      return "Error HTTP al subir incidencia: ${response.statusCode}";
    }
  }

  // ---------------------------
  //  Actualizar en la nube (API PHP)
  // ---------------------------
  static Future<String> actualizarIncidenciaRemoto({
    required Incidencia incidencia,
    required String token,
  }) async {
    final nombreBD = DatabaseConfig.databaseName;
    final uri = Uri.parse('$BASE_URL?Code=403');

    final body = {
      'Token': token,
      'Bd': nombreBD,
      'codigo': incidencia.codigo,
      'descripcion': incidencia.descripcion ?? '',
      'cif_empresa': incidencia.cifEmpresa ?? '',
      'computa': incidencia.computa ? '1' : '0',  // Añadido
    };

    final response = await http.post(
      uri,
      body: body,
    );

    if (response.statusCode == 200) {
      if (response.body.startsWith("OK")) {
        return "OK";
      } else {
        return "Error al actualizar incidencia: ${response.body}";
      }
    } else {
      return "Error HTTP al actualizar incidencia: ${response.statusCode}";
    }
  }

  // ---------------------------
  //  BORRADO REMOTO en la nube (API PHP)
  // ---------------------------
  static Future<String> eliminarIncidenciaRemoto({
    required String codigo,
    required String cifEmpresa,
    required String token,
  }) async {
    final nombreBD = DatabaseConfig.databaseName;
    final uri = Uri.parse('$BASE_URL?Code=402');
    final body = {
      'Token': token,
      'Bd': nombreBD,
      'codigo': codigo,
      'cif_empresa': cifEmpresa,
    };
    final response = await http.post(
      uri,
      body: body,
    );
    if (response.statusCode == 200) {
      if (response.body.startsWith("OK")) {
        return "OK";
      } else {
        return "Error al borrar incidencia: ${response.body}";
      }
    } else {
      return "Error HTTP al borrar incidencia: ${response.statusCode}";
    }
  }
}
