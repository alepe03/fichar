import '../models/historico.dart';
import '../db/database_helper.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart'; // Necesario para ConflictAlgorithm

int? firstIntValue(List<Map<String, Object?>> results) {
  if (results.isEmpty) return null;
  final value = results.first.values.first;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

class HistoricoService {
  static bool _syncInProgress = false;

  static Future<int> guardarFichajeLocal(Historico historico) async {
    print('[DEBUG][HistoricoService.guardarFichajeLocal] Intentando guardar: ${historico.toMap()}');
    final id = await DatabaseHelper.instance.insertHistorico(historico);
    print('[DEBUG][HistoricoService.guardarFichajeLocal] Guardado local solicitado con id $id.');
    return id;
  }

  static Future<bool> guardarFichajeRemoto(
    Historico historico,
    String token,
    String baseUrl,
    String nombreBD,
  ) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=301');
    final body = historico.toPhpBody();
    print('[DEBUG][guardarFichajeRemoto] URL: $url, BODY: $body');

    final response = await http.post(url, body: body);
    print('[DEBUG][guardarFichajeRemoto] STATUS: ${response.statusCode}, RESPUESTA: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Error guardando fichaje en la nube: ${response.body}');
    }

    // <-- NUEVO: detecta duplicado y NO reintentes, márcalo como sincronizado!
    if (response.body.contains('DUPLICADO')) {
      print('[SYNC] El UUID ya existe en la nube, se omite el reintento.');
      return true; // Se considera sincronizado aunque sea duplicado
    }

    if (!response.body.startsWith('OK')) {
      throw Exception('Error guardando fichaje en la nube: ${response.body}');
    }
    return true;
  }

  static Future<bool> _tryRemotoConRetry(
    Historico h,
    String token,
    String baseUrl,
    String bd,
  ) async {
    const maxRetries = 3;
    var delay = Duration(seconds: 2);

    for (var i = 0; i < maxRetries; i++) {
      try {
        return await guardarFichajeRemoto(h, token, baseUrl, bd);
      } catch (e) {
        print('[WARN][_tryRemotoConRetry] Intento ${i + 1} fallido para UUID ${h.uuid}: $e');
        // Si el mensaje es DUPLICADO, NO reintentes (ya lo cubre guardarFichajeRemoto devolviendo true)
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    return false;
  }

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
    print('[DEBUG][obtenerFichajesUsuario] Encontrados ${maps.length} registros para usuario=$usuario y empresa=$cifEmpresa');
    return maps.map((map) => Historico.fromMap(map)).toList();
  }

  static Future<int> sincronizarPendientes(
    String token,
    String baseUrl,
    String nombreBD,
  ) async {
    if (_syncInProgress) {
      print('[SYNC] Sincronización ya en curso, omitiendo nueva llamada.');
      return 0;
    }
    _syncInProgress = true;
    int syncedCount = 0;

    try {
      final pendientes = await DatabaseHelper.instance.historicosPendientes();
      print('🗒️ Pendientes encontradas: ${pendientes.length}');

      for (final h in pendientes) {
        print('→ Intentando enviar UUID ${h.uuid}');
        try {
          final ok = await _tryRemotoConRetry(h, token, baseUrl, nombreBD);
          if (ok) {
            await DatabaseHelper.instance.actualizarSincronizado(h.id, true);
            print('   ✅ UUID ${h.uuid} marcado como sync');
            syncedCount++;
          } else {
            print('   ⚠️ UUID ${h.uuid} no recibió OK del servidor');
          }
        } catch (e) {
          print('   ❌ Error en UUID ${h.uuid}: $e');
        }
      }

      print('📊 Total sincronizados: $syncedCount de ${pendientes.length}');
      return syncedCount;
    } finally {
      _syncInProgress = false;
    }
  }

  static Future<void> sincronizarHistoricoCompleto(
    String token,
    String baseUrl,
    String nombreBD,
  ) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    print('--- ENTRA EN sincronizarHistoricoCompleto ---');
    final url = Uri.parse('$baseUrl?Token=$token&Bd=$nombreBD&Code=300&cif_empresa=$nombreBD');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error al obtener histórico completo: ${response.statusCode}');
    }

    final csvString = response.body;
    List<List<dynamic>> csvTable = const CsvToListConverter(fieldDelimiter: ';').convert(csvString);

    if (csvTable.isNotEmpty) {
      csvTable.removeAt(0); // Quitar cabecera
    }

    if (csvTable.isEmpty) {
      print('[HistoricoService] No hay registros para sincronizar.');
      return;
    }

    final db = await DatabaseHelper.instance.database;

    // Sube primero los pendientes antes de borrar (muy recomendable)
    await sincronizarPendientes(token, baseUrl, nombreBD);

    // Borra solo los fichajes sincronizados para NO perder los locales aún no subidos
    await db.delete('historico', where: 'sincronizado = 1 AND cif_empresa = ?', whereArgs: [nombreBD]);

    for (var row in csvTable) {
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
        'latitud': row[11] != null && row[11].toString().isNotEmpty
            ? double.tryParse(row[11].toString())
            : null,
        'longitud': row[12] != null && row[12].toString().isNotEmpty
            ? double.tryParse(row[12].toString())
            : null,
        'uuid': row.length > 13 && row[13].toString().isNotEmpty ? row[13].toString() : '', // <--- UUID desde CSV
        'sincronizado': 1,
      };

      print('[DEBUG] Insertando fila: $data');
      await db.insert(
        'historico',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace, // ¡¡IMPORTANTE para NO duplicar!!
      );
    }

    final count = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM historico WHERE cif_empresa = ?', [nombreBD]),
    );
    print('[DEBUG][sincronizarHistoricoCompleto] Sincronización completada, $count registros insertados.');
  }
}
