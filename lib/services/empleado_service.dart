import 'package:http/http.dart' as http;
import '../models/empleado.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class EmpleadoService {
  static Future<void> descargarYGuardarEmpleados(
      String cifEmpresa, String token, String baseUrl) async {
    // Validación profesional del parámetro
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    const nombreBD = 'qame400';

    final url = Uri.parse(
      '$baseUrl?Token=$token&Bd=$nombreBD&Code=200&cif_empresa=$cifEmpresa',
    );

    print('Descargando empleados desde: $url'); // Log útil para depuración

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');
      if (lines.isNotEmpty) lines.removeAt(0); // Quita cabecera

      final List<Empleado> empleados = [];
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          empleados.add(Empleado.fromCsv(line));
        } catch (e) {
          print('Error parseando línea CSV: $line\nError: $e');
          // Puedes decidir aquí si abortar todo, omitir solo esa línea, etc.
        }
      }

      final db = await DatabaseHelper.instance.database;
      // Borra solo empleados de esa empresa
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
      throw Exception('Error descargando empleados: ${response.statusCode}');
    }
  }
}
