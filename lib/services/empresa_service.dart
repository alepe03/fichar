// lib/services/empresa_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/empresa.dart';
import '../config.dart'; // Para BASE_URL

class EmpresaService {
  /// 1) Inserta una empresa en la API (Code=501)
  static Future<String> insertarEmpresaRemoto({
    required Empresa empresa,
    required String token,
    required int maxUsuarios,
  }) async {
    final uri = Uri.parse('$BASE_URL?Code=501');
    final body = {
      'Token': token,
      'cif_empresa': empresa.cifEmpresa,
      'nombre': empresa.nombre,
      'direccion': empresa.direccion ?? '',
      'telefono': empresa.telefono ?? '',
      'codigo_postal': empresa.codigoPostal ?? '',
      'email': empresa.email ?? '',
      'basedatos': empresa.basedatos ?? '',
      'max_usuarios': maxUsuarios.toString(),
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Error de conexión: ${response.statusCode}');
    }
    final text = response.body.trim();
    if (text.startsWith('OK;')) {
      return text;
    } else {
      throw Exception('API Error: $text');
    }
  }

  /// 2) Lista todas las empresas (Code=500), parseando en un isolate
  static Future<List<Empresa>> listarEmpresasRemoto({
    required String token,
  }) async {
    final uri = Uri.parse('$BASE_URL?Token=$token&Code=500');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al listar empresas: ${response.statusCode}');
    }
    final body = response.body.trim();
    if (body.startsWith('ERROR;')) {
      throw Exception('API: $body');
    }

    // Aquí offloadeamos el parseo a otro isolate
    return compute(_parseEmpresas, body);
  }

  /// 3) Actualiza todos los campos de una empresa (Code=503)
  static Future<void> actualizarEmpresaRemoto({
    required Empresa empresa,
    required int maxUsuarios,
    required String token,
  }) async {
    final uri = Uri.parse('$BASE_URL?Code=503');
    final body = {
      'Token': token,
      'cif_empresa': empresa.cifEmpresa,
      'nombre': empresa.nombre,
      'direccion': empresa.direccion ?? '',
      'telefono': empresa.telefono ?? '',
      'codigo_postal': empresa.codigoPostal ?? '',
      'email': empresa.email ?? '',
      'basedatos': empresa.basedatos ?? '',
      'max_usuarios': maxUsuarios.toString(),
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Error de conexión: ${response.statusCode}');
    }
    final text = response.body.trim();
    if (!text.startsWith('OK;')) {
      throw Exception('API: $text');
    }
  }
}

/// Función de parseo que correrá en un isolate
List<Empresa> _parseEmpresas(String body) {
  final lines = LineSplitter.split(body).toList();
  if (lines.length < 2) return [];

  final headers = lines.first.split(';');
  final empresas = <Empresa>[];

  for (var i = 1; i < lines.length; i++) {
    final cols = lines[i].split(';');
    if (cols.length < headers.length) continue;
    final map = <String, String>{};
    for (var j = 0; j < headers.length; j++) {
      map[headers[j]] = cols[j];
    }
    empresas.add(Empresa.fromCsvMap(map));
  }

  return empresas;
}
