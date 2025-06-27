import 'package:http/http.dart' as http;
import '../models/incidencia.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class IncidenciaService {
  static Future<void> descargarYGuardarIncidencias(
      String cifEmpresa, String token, String baseUrl) async {
    // Valida la URL base
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }
    const nombreBD = 'qame400';
    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=400&cif_empresa=$cifEmpresa');
    print('Descargando incidencias desde: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');
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
}
