import 'package:http/http.dart' as http;          
import '../models/sucursal.dart';                   
import '../db/database_helper.dart';                
import 'package:sqflite/sqflite.dart';            
import 'package:flutter/foundation.dart'; // Para compute
import '../config.dart'; // Para DatabaseConfig

// Servicio para descargar y guardar sucursales
class SucursalService {
  // Función top-level para parsear CSV en otro isolate
  static List<Sucursal> parseSucursalesCsv(String csvBody) {
    final lines = csvBody.split('\n');
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
    return sucursales;
  }

  // Descarga las sucursales de la API y las guarda en la base de datos local
  static Future<void> descargarYGuardarSucursales(
      String cifEmpresa, String token, String baseUrl) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    final nombreBD = DatabaseConfig.databaseName; // Nombre de la base de datos en el backend

    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=600&cif_empresa=$cifEmpresa');
    print('Descargando sucursales desde: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Parsear en isolate para no bloquear hilo UI
      final sucursales = await compute(parseSucursalesCsv, response.body);

      final db = await DatabaseHelper.instance.database;
      await db.delete('sucursales', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
      for (var sucursal in sucursales) {
        await db.insert(
          'sucursales',
          sucursal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      print('Sucursales guardadas correctamente: ${sucursales.length}');
    } else {
      throw Exception('Error descargando sucursales: ${response.statusCode}');
    }
  }
}
