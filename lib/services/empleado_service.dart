import 'package:http/http.dart' as http;              
import '../models/empleado.dart';                    
import '../db/database_helper.dart';                 
import 'package:sqflite/sqflite.dart';                
import '../config.dart'; 
import 'package:flutter/foundation.dart'; // Import necesario para compute

class EmpleadoService {
  // Función top-level para parsear CSV en otro isolate
  static List<Empleado> parseEmpleadosCsv(String csvBody) {
    final lines = csvBody.split('\n');
    if (lines.isNotEmpty) lines.removeAt(0); // Quitar cabecera CSV

    final List<Empleado> empleados = [];
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        empleados.add(Empleado.fromCsv(line));
      } catch (e) {
        print('Error parseando línea CSV: $line\nError: $e');
      }
    }
    return empleados;
  }

  // Descarga los empleados desde la API y guarda en la base local SQLite
  static Future<void> descargarYGuardarEmpleados(
      String cifEmpresa, String token, String baseUrl) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    const nombreBD = 'qame400'; // Nombre de la base de datos en el backend

    final url = Uri.parse(
      '$baseUrl?Token=$token&Bd=$nombreBD&Code=200&cif_empresa=$cifEmpresa',
    );

    print('Descargando empleados desde: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Aquí usamos compute para hacer el parseo en otro isolate
      final List<Empleado> empleados = await compute(parseEmpleadosCsv, response.body);

      final db = await DatabaseHelper.instance.database;
      await db.delete('empleados', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);

      for (var emp in empleados) {
        await db.insert(
          'empleados',
          emp.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      print('Empleados guardados correctamente: ${empleados.length}');
    } else {
      throw Exception('Error descargando empleados: ${response.statusCode}');
    }
  }

  // Inserta un empleado en la API (alta remota)
  static Future<String> insertarEmpleadoRemoto({
    required Empleado empleado,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=201');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'Token': token,
        'usuario': empleado.usuario,
        'cif_empresa': empleado.cifEmpresa,
        'direccion': empleado.direccion ?? '',
        'poblacion': empleado.poblacion ?? '',
        'codigo_postal': empleado.codigoPostal ?? '',
        'telefono': empleado.telefono ?? '',
        'email': empleado.email ?? '',
        'nombre': empleado.nombre ?? '',
        'dni': empleado.dni ?? '',
        'rol': empleado.rol ?? '',
        'password_hash': empleado.passwordHash ?? '',
        'puede_localizar': empleado.puedeLocalizar.toString(),
      },
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }

  // Actualiza un empleado en la API (modificación remota)
  static Future<String> actualizarEmpleadoRemoto({
    required Empleado empleado,
    required String usuarioOriginal,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=203');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'Token': token,
        'usuario_original': usuarioOriginal,
        'usuario': empleado.usuario,
        'cif_empresa': empleado.cifEmpresa,
        'direccion': empleado.direccion ?? '',
        'poblacion': empleado.poblacion ?? '',
        'codigo_postal': empleado.codigoPostal ?? '',
        'telefono': empleado.telefono ?? '',
        'email': empleado.email ?? '',
        'nombre': empleado.nombre ?? '',
        'dni': empleado.dni ?? '',
        'rol': empleado.rol ?? '',
        'password_hash': empleado.passwordHash ?? '',
        'puede_localizar': empleado.puedeLocalizar.toString(),
      },
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }

  // Elimina un empleado en la API (baja remota)
  static Future<String> eliminarEmpleadoRemoto({
    required String usuario,
    required String cifEmpresa,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=202');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'Token': token,
        'usuario': usuario,
        'cif_empresa': cifEmpresa,
      },
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }
}
