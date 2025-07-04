import 'package:http/http.dart' as http;              
import '../models/empleado.dart';                    
import '../db/database_helper.dart';                 
import 'package:sqflite/sqflite.dart';                
import '../config.dart'; 

class EmpleadoService {
  // Descarga los empleados desde la API y guarda en la base local SQLite
  static Future<void> descargarYGuardarEmpleados(
      String cifEmpresa, String token, String baseUrl) async {
    // Valida que la URL base sea correcta
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    const nombreBD = 'qame400'; // Nombre de la base de datos en el backend

    // Construye la URL para la petición GET de empleados
    final url = Uri.parse(
      '$baseUrl?Token=$token&Bd=$nombreBD&Code=200&cif_empresa=$cifEmpresa',
    );

    print('Descargando empleados desde: $url');

    final response = await http.get(url); // Hace la petición GET

    if (response.statusCode == 200) {
      // Si la respuesta es correcta, procesa el CSV recibido
      final lines = response.body.split('\n');
      if (lines.isNotEmpty) lines.removeAt(0); // Quitar cabecera CSV

      final List<Empleado> empleados = [];
      for (var line in lines) {
        if (line.trim().isEmpty) continue; // Omite líneas vacías
        try {
          empleados.add(Empleado.fromCsv(line)); // Parsea cada línea a un Empleado
        } catch (e) {
          print('Error parseando línea CSV: $line\nError: $e');
        }
      }

      final db = await DatabaseHelper.instance.database;
      // Borra antiguos antes de insertar nuevos para evitar duplicados
      await db.delete('empleados', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);

      // Inserta todos usando REPLACE para evitar errores de duplicado
      for (var emp in empleados) {
        await db.insert(
          'empleados',
          emp.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      print('Empleados guardados correctamente: ${empleados.length}');
    } else {
      // Si la respuesta no es 200, lanza una excepción
      throw Exception('Error descargando empleados: ${response.statusCode}');
    }
  }

  // Inserta un empleado en la API (alta remota)
  static Future<String> insertarEmpleadoRemoto({
    required Empleado empleado,
    required String token,
  }) async {
    // Construye la URL para la petición POST de alta de empleado
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
      },
    );
    if (response.statusCode == 200) {
      return response.body; // Respuesta tipo "OK;Empleado insertado" o error
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
    // Construye la URL para la petición POST de baja de empleado
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
      return response.body; // Respuesta tipo "OK;Empleado eliminado" o error
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }

  // (Opcional) Podrías añadir método para actualizar empleado remoto (si la API lo soporta)
}
