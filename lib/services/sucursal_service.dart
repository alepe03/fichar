import 'package:http/http.dart' as http;
import '../models/sucursal.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class SucursalService {
  static Future<void> descargarYGuardarSucursales(
      String cifEmpresa, String token, String baseUrl) async {
    // Validación robusta de la URL
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    const nombreBD = 'qame400';
    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=600&cif_empresa=$cifEmpresa');
    print('Descargando sucursales desde: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');
      if (lines.isNotEmpty) lines.removeAt(0);

      final List<Sucursal> sucursales = [];
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          sucursales.add(Sucursal.fromCsv(line));
        } catch (e) {
          print('Error parseando línea CSV de sucursal: $line\nError: $e');
        }
      }

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
