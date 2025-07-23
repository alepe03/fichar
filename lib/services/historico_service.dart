import '../models/historico.dart';
import '../db/database_helper.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

/// Función auxiliar para obtener el primer entero de la consulta SQL
int? firstIntValue(List<Map<String, Object?>> results) {
  if (results.isEmpty) return null;
  final value = results.first.values.first;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

/// Servicio para gestionar el histórico de fichajes (local y remoto)
class HistoricoService {
  /// Guarda un nuevo fichaje en la base de datos local SQLite.
  static Future<int> guardarFichajeLocal(Historico historico) async {
    print('[DEBUG][HistoricoService.guardarFichajeLocal] Intentando guardar: ${historico.toMap()}');
    final id = await DatabaseHelper.instance.insertHistorico(historico);
    print('[DEBUG][HistoricoService.guardarFichajeLocal] Guardado local solicitado con id $id.');
    return id;
  }

  /// Guarda un fichaje en la nube (MySQL a través de PHP API)
  static Future<bool> guardarFichajeRemoto(
    Historico historico,
    String token,
    String baseUrl,
    String nombreBD,
  ) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    print('--- ENTRA EN guardarFichajeRemoto ---');
    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=301');

    final body = historico.toPhpBody();
    print('BODY ENVIADO: $body');

    final response = await http.post(
      url,
      body: body,
    );

    print('--- ENVÍO PHP ---');
    print('URL: $url');
    print('BODY RESPUESTA: ${response.body}');
    print('STATUS: ${response.statusCode}');

    if (response.statusCode != 200 || !response.body.startsWith('OK')) {
      throw Exception('Error guardando fichaje en la nube: ${response.body}');
    }
    return true;
  }

  /// (Opcional) Obtener todos los fichajes de un usuario (local)
  static Future<List<Historico>> obtenerFichajesUsuario(
    String usuario,
    String cifEmpresa,
  ) async {
    final maps = await DatabaseHelper.instance.database.then(
      (db) => db.query(
        'historico',
        where: 'usuario = ? AND cif_empresa = ?',
        whereArgs: [usuario, cifEmpresa],
        orderBy: 'fecha_entrada DESC',
      ),
    );
    print('[DEBUG][HistoricoService.obtenerFichajesUsuario] Encontrados ${maps.length} registros para usuario=$usuario y empresa=$cifEmpresa');
    return maps.map((map) => Historico.fromMap(map)).toList();
  }

  /// Sincroniza los fichajes pendientes guardados localmente, en paralelo
  static Future<void> sincronizarPendientes(
    String token,
    String baseUrl,
    String nombreBD,
  ) async {
    final pendientes = await DatabaseHelper.instance.historicosPendientes();

    final futures = pendientes.map((h) async {
      try {
        await guardarFichajeRemoto(h, token, baseUrl, nombreBD);
        await DatabaseHelper.instance.actualizarSincronizado(h.id, true);
      } catch (e) {
        print('Error sincronizando id ${h.id}: $e');
      }
    });

    await Future.wait(futures);
  }

  /// Sincroniza TODO el histórico desde la nube y actualiza la base local
  /// Descarga con GET Code=300, parsea CSV y reemplaza la tabla local.
  static Future<void> sincronizarHistoricoCompleto(
    String token,
    String baseUrl,
    String nombreBD,
  ) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    print('--- ENTRA EN sincronizarHistoricoCompleto ---');

    // CORRECCIÓN IMPORTANTE: Añadir cif_empresa a la URL para que la API devuelva datos filtrados
    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=300&cif_empresa=$nombreBD');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error al obtener histórico completo: ${response.statusCode}');
    }

    final csvString = response.body;
    final maxLength = csvString.length < 200 ? csvString.length : 200;
    print('CSV recibido: ${csvString.substring(0, maxLength)}...');

    // Parsear CSV con delimitador ';'
    List<List<dynamic>> csvTable = const CsvToListConverter(fieldDelimiter: ';').convert(csvString);

    // Eliminar cabecera si existe
    if (csvTable.isNotEmpty) {
      csvTable.removeAt(0);
    }

    if (csvTable.isEmpty) {
      print('[HistoricoService] No hay registros para sincronizar.');
      return;
    }

    final db = await DatabaseHelper.instance.database;

    // Borrar historicos locales antes de insertar nuevos
    await db.delete('historico', where: 'cif_empresa = ?', whereArgs: [nombreBD]);

    for (var row in csvTable) {
      // Validar que la fila tiene al menos 13 columnas (para evitar errores)
      if (row.length < 13) {
        print('[WARN] Fila incompleta ignorada: $row');
        continue;
      }

      final data = {
        'id': int.tryParse(row[0].toString()) ?? 0,
        'cif_empresa': row[1].toString(),
        'usuario': row[2].toString(),
        'fecha_entrada': row[3]?.toString(),
        'fecha_salida': row[4]?.toString(),
        'tipo': row[5].toString(),
        'incidencia_codigo': row[6]?.toString(),
        'observaciones': row[7]?.toString(),
        'nombre_empleado': row[8].toString(),
        'dni_empleado': row[9].toString(),
        'id_sucursal': row[10]?.toString(),
        'latitud': row[11] != null && row[11].toString().isNotEmpty ? double.tryParse(row[11].toString()) : null,
        'longitud': row[12] != null && row[12].toString().isNotEmpty ? double.tryParse(row[12].toString()) : null,
        'sincronizado': 1,
      };

      print('[DEBUG] Insertando fila: $data');

      await db.insert('historico', data);
    }

    final count = firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM historico WHERE cif_empresa = ?', [nombreBD]));
    print('[DEBUG][HistoricoService.sincronizarHistoricoCompleto] Sincronización completada, $count registros insertados.');
  }
}
