import 'package:http/http.dart' as http;           // Para hacer peticiones HTTP
import '../models/incidencia.dart';                 // Modelo de incidencia
import '../db/database_helper.dart';                // Helper para la base de datos local
import 'package:sqflite/sqflite.dart';             // Para operaciones con SQLite

// Servicio para descargar y guardar incidencias
class IncidenciaService {
  // Descarga las incidencias de la API y las guarda en la base de datos local
  static Future<void> descargarYGuardarIncidencias(
      String cifEmpresa, String token, String baseUrl) async {
    // Valida que la URL base sea correcta
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }
    const nombreBD = 'qame400'; // Nombre de la base de datos en el backend

    // Construye la URL para la petición
    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=400&cif_empresa=$cifEmpresa');
    print('Descargando incidencias desde: $url');

    final response = await http.get(url); // Hace la petición GET

    if (response.statusCode == 200) {
      // Si la respuesta es correcta, procesa el CSV recibido
      final lines = response.body.split('\n');
      if (lines.isNotEmpty) lines.removeAt(0); // Quita la cabecera

      final List<Incidencia> incidencias = [];
      for (var line in lines) {
        if (line.trim().isEmpty) continue; // Omite líneas vacías
        try {
          incidencias.add(Incidencia.fromCsv(line)); // Parsea cada línea a una Incidencia
        } catch (e) {
          print('Error parseando línea CSV de incidencia: $line\nError: $e');
        }
      }

      final db = await DatabaseHelper.instance.database;
      // Borra solo incidencias de esa empresa antes de insertar las nuevas
      await db.delete('incidencias', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
      // Inserta todas usando REPLACE para evitar errores de duplicado
      for (var inc in incidencias) {
        await db.insert(
          'incidencias',
          inc.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      print('Incidencias guardadas correctamente: ${incidencias.length}');
    } else {
      // Si la respuesta no es 200, lanza una excepción
      throw Exception('Error descargando incidencias: ${response.statusCode}');
    }
  }
}
