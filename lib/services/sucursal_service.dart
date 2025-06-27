import 'package:http/http.dart' as http;           // Para hacer peticiones HTTP
import '../models/sucursal.dart';                   // Modelo de sucursal
import '../db/database_helper.dart';                // Helper para la base de datos local
import 'package:sqflite/sqflite.dart';             // Para operaciones con SQLite

// Servicio para descargar y guardar sucursales
class SucursalService {
  // Descarga las sucursales de la API y las guarda en la base de datos local
  static Future<void> descargarYGuardarSucursales(
      String cifEmpresa, String token, String baseUrl) async {
    // Valida que la URL base sea correcta
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    const nombreBD = 'qame400'; // Nombre de la base de datos en el backend

    // Construye la URL para la petición
    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=600&cif_empresa=$cifEmpresa');
    print('Descargando sucursales desde: $url');

    final response = await http.get(url); // Hace la petición GET

    if (response.statusCode == 200) {
      // Si la respuesta es correcta, procesa el CSV recibido
      final lines = response.body.split('\n');
      if (lines.isNotEmpty) lines.removeAt(0); // Quita la cabecera

      final List<Sucursal> sucursales = [];
      for (var line in lines) {
        if (line.trim().isEmpty) continue; // Omite líneas vacías
        try {
          sucursales.add(Sucursal.fromCsv(line)); // Parsea cada línea a una Sucursal
        } catch (e) {
          print('Error parseando línea CSV de sucursal: $line\nError: $e');
        }
      }

      final db = await DatabaseHelper.instance.database;
      // Borra solo sucursales de esa empresa antes de insertar las nuevas
      await db.delete('sucursales', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
      // Inserta todas usando REPLACE para evitar errores de duplicado
      for (var sucursal in sucursales) {
        await db.insert(
          'sucursales',
          sucursal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      print('Sucursales guardadas correctamente: ${sucursales.length}');
    } else {
      // Si la respuesta no es 200, lanza una excepción
      throw Exception('Error descargando sucursales: ${response.statusCode}');
    }
  }
}
