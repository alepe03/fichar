// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/empleado.dart';
import '../config.dart';

class AuthService {
  /// Login local sin cambios
  static Future<Empleado?> loginLocal(
    String usuario,
    String password,
    String cifEmpresa,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'empleados',
      where: 'usuario = ? AND cif_empresa = ? AND activo = 1',
      whereArgs: [usuario, cifEmpresa],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final empleado = Empleado.fromMap(results.first);
    if (!_validarPassword(password, empleado.passwordHash)) {
      return null;
    }
    return empleado;
  }

  /// Cambiar contraseña: primero al servidor (Code=207), luego local
  static Future<bool> cambiarPassword({
    required String usuario,
    required String cifEmpresa,
    required String actual,
    required String nueva,
  }) async {
    // 1) Obtener token y baseUrl guardados
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';
    if (token.isEmpty || baseUrl.isEmpty) return false;

    // 2) Llamada POST al endpoint remoto ?Code=207
    final uri = Uri.parse('$baseUrl?Code=207');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'Token': token,
        'usuario': usuario,
        'cif_empresa': cifEmpresa,
        'actual': actual,
        'nueva': nueva,
      },
    );
    if (resp.statusCode != 200 || !resp.body.startsWith('OK;')) {
      return false;
    }

    // 3) Si el servidor respondió OK, actualizar también en SQLite local
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'empleados',
      {'password_hash': nueva},
      where: 'usuario = ? AND cif_empresa = ?',
      whereArgs: [usuario, cifEmpresa],
    );

    return true;
  }

  /// Comparación simple de password plano vs hash
  static bool _validarPassword(String ingresada, String? hash) {
    if (hash == null) return false;
    return ingresada == hash;
  }
}
