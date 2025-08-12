// lib/services/empresa_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/empresa.dart';
import '../config.dart'; // BASE_URL

class EmpresaService {
  // Normaliza doubles a string con punto decimal
  static String _fmtCuota(double? v) {
    if (v == null) return '';
    // evita coma decimal si el valor viniera ya con coma en algún sitio
    return v.toString().replaceAll(',', '.');
  }

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
      // NUEVO
      'cuota': _fmtCuota(empresa.cuota),
      'observaciones': empresa.observaciones ?? '',
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
      // NUEVO
      'cuota': _fmtCuota(empresa.cuota),
      'observaciones': empresa.observaciones ?? '',
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
  final lines = const LineSplitter().convert(body);
  if (lines.length < 2) return [];

  // Limpia cabeceras por posibles \r y descarta la cabecera vacía si hay ';' final
  final rawHeaders = lines.first.split(';').map((h) => h.trim().replaceAll('\r', '')).toList();
  final headers = rawHeaders.where((h) => h.isNotEmpty).toList();

  final empresas = <Empresa>[];

  for (var i = 1; i < lines.length; i++) {
    final cols = lines[i].split(';');
    if (cols.isEmpty || cols.length < 2) continue; // línea vacía o basura

    final map = <String, String>{};
    final len = cols.length < headers.length ? cols.length : headers.length;
    for (var j = 0; j < len; j++) {
      map[headers[j]] = cols[j].replaceAll('\r', '');
    }
    // Relleno por si el backend dejó el último valor vacío antes del ';'
    for (var j = len; j < headers.length; j++) {
      map[headers[j]] = '';
    }

    empresas.add(Empresa.fromCsvMap(map));
  }

  return empresas;
}
