import 'package:http/http.dart' as http;           // Para hacer peticiones HTTP
import '../models/empleado.dart';                   // Modelo de empleado
import '../db/database_helper.dart';                // Helper para la base de datos local
import 'package:sqflite/sqflite.dart';             // Para operaciones con SQLite

class EmpleadoService {
  // Descarga los empleados de la API y los guarda en la base de datos local
  static Future<void> descargarYGuardarEmpleados(
      String cifEmpresa, String token, String baseUrl) async {
    // Valida que la URL base sea correcta
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    const nombreBD = 'qame400'; // Nombre de la base de datos en el backend

    // Construye la URL para la petición
    final url = Uri.parse(
      '$baseUrl?Token=$token&Bd=$nombreBD&Code=200&cif_empresa=$cifEmpresa',
    );

    print('Descargando empleados desde: $url'); // Log útil para depuración

    final response = await http.get(url); // Hace la petición GET

    if (response.statusCode == 200) {
      // Si la respuesta es correcta, procesa el CSV recibido
      final lines = response.body.split('\n');
      if (lines.isNotEmpty) lines.removeAt(0); // Quita cabecera

      final List<Empleado> empleados = [];
      for (var line in lines) {
        if (line.trim().isEmpty) continue; // Omite líneas vacías
        try {
          empleados.add(Empleado.fromCsv(line)); // Parsea cada línea a un Empleado
        } catch (e) {
          print('Error parseando línea CSV: $line\nError: $e');
          // Puedes decidir aquí si abortar todo, omitir solo esa línea, etc.
        }
      }

      final db = await DatabaseHelper.instance.database;
      // Borra solo empleados de esa empresa antes de insertar los nuevos
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
}
