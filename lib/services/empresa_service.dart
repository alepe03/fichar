import 'package:http/http.dart' as http;
import '../models/empresa.dart';
import '../config.dart'; // Para BASE_URL

class EmpresaService {
  // Inserta una empresa en la API
  static Future<String> insertarEmpresaRemoto({
    required Empresa empresa,
    required String token,
    required int maxUsuarios, // Este campo lo tendrás que guardar en la tabla (añádelo al form)
  }) async {
    final url = Uri.parse('$BASE_URL?Code=501');

    final body = {
      'Token': token,
      'cif_empresa': empresa.cifEmpresa,
      'nombre': empresa.nombre,
      'direccion': empresa.direccion ?? '',
      'telefono': empresa.telefono ?? '',
      'codigo_postal': empresa.codigoPostal ?? '',
      'email': empresa.email ?? '',
      'basedatos': empresa.basedatos ?? '',
      'max_usuarios': maxUsuarios.toString(),  // <--- CAMBIADO AQUÍ
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      final bodyResp = response.body;
      if (bodyResp.startsWith('OK;')) {
        return bodyResp;
      } else if (bodyResp.startsWith('ERROR;')) {
        throw Exception(bodyResp);
      } else {
        throw Exception('Respuesta inesperada del servidor: $bodyResp');
      }
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }
}
