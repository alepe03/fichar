import '../models/historico.dart';           
import '../db/database_helper.dart';         
import 'package:http/http.dart' as http;    

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
}
