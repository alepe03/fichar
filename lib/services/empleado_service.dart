import 'package:http/http.dart' as http;
import '../models/empleado.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import '../config.dart';
import 'package:flutter/foundation.dart';

class EmpleadoService {
  // ---------------------------------------------------------------------------
  // Parser CSV en isolate (no bloquea el UI thread)
  // ---------------------------------------------------------------------------
  static List<Empleado> parseEmpleadosCsv(String csvBody) {
    final lines = csvBody.split('\n');
    if (lines.isNotEmpty) lines.removeAt(0); // Quitar cabecera CSV

    final List<Empleado> empleados = [];
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        empleados.add(Empleado.fromCsv(line));
      } catch (e) {
        // No rompemos la importación por una línea mal formada
        // (puedes loguearlo a analytics si quieres)
        // ignore: avoid_print
        print('Error parseando línea CSV: $line\nError: $e');
      }
    }
    return empleados;
  }

  // ---------------------------------------------------------------------------
  // Descarga y persistencia local de empleados
  // ---------------------------------------------------------------------------
  static Future<void> descargarYGuardarEmpleados(
    String cifEmpresa,
    String token,
    String baseUrl,
  ) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    final nombreBD = DatabaseConfig.databaseName;

    final url = Uri.parse(
      '$baseUrl?Token=$token&Bd=$nombreBD&Code=200&cif_empresa=$cifEmpresa',
    );

    // ignore: avoid_print
    print('Descargando empleados desde: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<Empleado> empleados =
          await compute(parseEmpleadosCsv, response.body);

      final db = await DatabaseHelper.instance.database;

      await db.delete('empleados',
          where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);

      for (var emp in empleados) {
        await db.insert(
          'empleados',
          emp.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // ignore: avoid_print
      print('Empleados guardados correctamente: ${empleados.length}');
    } else {
      throw Exception('Error descargando empleados: ${response.statusCode}');
    }
  }

  // Sincronización completa (alias del anterior para mayor claridad)
  static Future<void> sincronizarEmpleadosCompleto(
    String token,
    String baseUrl,
    String cifEmpresa,
  ) async {
    if (baseUrl.trim().isEmpty || !baseUrl.startsWith('http')) {
      throw ArgumentError("El parámetro baseUrl es inválido: '$baseUrl'");
    }

    final nombreBD = DatabaseConfig.databaseName;

    final url = Uri.parse(
      '$baseUrl?Token=$token&Bd=$nombreBD&Code=200&cif_empresa=$cifEmpresa',
    );

    // ignore: avoid_print
    print('Descargando empleados para sincronización completa desde: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<Empleado> empleados =
          await compute(parseEmpleadosCsv, response.body);

      final db = await DatabaseHelper.instance.database;

      await db.delete('empleados',
          where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);

      for (var emp in empleados) {
        await db.insert(
          'empleados',
          emp.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // ignore: avoid_print
      print('Empleados sincronizados y guardados localmente: ${empleados.length}');
    } else {
      throw Exception(
          'Error descargando empleados para sincronización: ${response.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // Inserción remota (alta): devuelve OK + id/pin o lanza Exception con mensaje
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> insertarEmpleadoRemoto({
    required Empleado empleado,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=201');

    final body = {
      'Token': token,
      'usuario': empleado.usuario,
      'cif_empresa': empleado.cifEmpresa,
      'direccion': empleado.direccion ?? '',
      'poblacion': empleado.poblacion ?? '',
      'codigo_postal': empleado.codigoPostal ?? '',
      'telefono': empleado.telefono ?? '',
      'email': empleado.email ?? '',
      'nombre': empleado.nombre ?? '',
      'dni': empleado.dni ?? '',
      'rol': empleado.rol ?? '',
      'puede_localizar': empleado.puedeLocalizar.toString(),
      'activo': empleado.activo.toString(),
    };

    // Solo añadir password si viene informada (creación)
    if (empleado.passwordHash != null && empleado.passwordHash!.isNotEmpty) {
      body['password_hash'] = empleado.passwordHash!;
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      final bodyResp = response.body.trim();

      // Detecta límite alcanzado (texto del backend puede variar:
      // "Límite de usuarios activos alcanzado", "No quedan plazas activas", etc.)
      final isLimitError = bodyResp.startsWith('ERROR;') &&
          (bodyResp.contains('Límite') || bodyResp.contains('No quedan')) &&
          bodyResp.contains('activos');

      if (isLimitError) {
        // Lanzamos excepción con un mensaje amigable para mostrar en SnackBar
        throw Exception(
          'No se puede crear el empleado: se ha alcanzado el límite de usuarios activos permitidos para la empresa.',
        );
      } else if (bodyResp.startsWith('OK;')) {
        // Ejemplo: "OK; Empleado insertado; ID=3; PIN=0833"
        final idReg = RegExp(r'ID=(\d+)');
        final pinReg = RegExp(r'PIN=(\d{4})');
        final id = idReg.firstMatch(bodyResp)?.group(1);
        final pin = pinReg.firstMatch(bodyResp)?.group(1);

        return {
          'ok': true,
          'mensaje': bodyResp,
          'id': id,
          'pin': pin,
        };
      } else if (bodyResp.startsWith('ERROR;')) {
        // Propaga el error textual del backend
        throw Exception(bodyResp);
      } else {
        throw Exception('Respuesta inesperada del servidor: $bodyResp');
      }
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }

  // ---------------------------------------------------------------------------
  // Actualización remota: devuelve el body (OK; ... / ERROR; ...)
  // Si el backend indica cupo lleno al activar/cambiar rol, devolvemos
  // un mensaje amigable (no exception) para que el Provider lo muestre tal cual.
  // ---------------------------------------------------------------------------
  static Future<String> actualizarEmpleadoRemoto({
    required Empleado empleado,
    required String usuarioOriginal,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=203');

    final body = {
      'Token': token,
      'usuario_original': usuarioOriginal,
      'usuario': empleado.usuario,
      'cif_empresa': empleado.cifEmpresa,
      'direccion': empleado.direccion ?? '',
      'poblacion': empleado.poblacion ?? '',
      'codigo_postal': empleado.codigoPostal ?? '',
      'telefono': empleado.telefono ?? '',
      'email': empleado.email ?? '',
      'nombre': empleado.nombre ?? '',
      'dni': empleado.dni ?? '',
      'rol': empleado.rol ?? '',
      'puede_localizar': empleado.puedeLocalizar.toString(),
      'activo': empleado.activo.toString(),
    };

    // Agregar password solo si viene informada
    if (empleado.passwordHash != null && empleado.passwordHash!.isNotEmpty) {
      body['password_hash'] = empleado.passwordHash!;
    }

    // Permitir actualizar el PIN si tu modelo lo trae (campo opcional)
    try {
      // Si tu clase Empleado ya tiene pinFichaje tipado, reemplaza esto por empleado.pinFichaje
      final dynamicPin = (empleado as dynamic).pinFichaje;
      if (dynamicPin != null && dynamicPin.toString().isNotEmpty) {
        body['pin_fichaje'] = dynamicPin.toString();
      }
    } catch (_) {
      // Ignora si el modelo no tiene pinFichaje en esta build
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      final bodyResp = response.body.trim();

      // Mensajes de cupo lleno (activar o cambiar de supervisor -> rol que cuenta)
      final isNoSlots = bodyResp.startsWith('ERROR;') &&
          (bodyResp.contains('No quedan plazas activas') ||
              (bodyResp.contains('Límite') && bodyResp.contains('activos')));

      if (isNoSlots) {
        return 'ERROR; No quedan plazas activas en el plan de la empresa. Da de baja a alguien o amplía el plan.';
      }

      // Devuelve la respuesta tal cual (el Provider decide si es OK o ERROR)
      return bodyResp;
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }

  // ---------------------------------------------------------------------------
  // Eliminación remota
  // ---------------------------------------------------------------------------
  static Future<String> eliminarEmpleadoRemoto({
    required String usuario,
    required String cifEmpresa,
    required String token,
  }) async {
    final url = Uri.parse('$BASE_URL?Code=202');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'Token': token,
        'usuario': usuario,
        'cif_empresa': cifEmpresa,
      },
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Error al conectar con el servidor: ${response.statusCode}");
    }
  }
}
