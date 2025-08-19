import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/empleado.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../models/horario_empleado.dart';

import '../db/database_helper.dart';
import '../services/empleado_service.dart';
import '../services/incidencia_service.dart';
import '../services/historico_service.dart';
import '../services/horarios_service.dart';
import '../config.dart'; // Para DatabaseConfig

/// Provider principal para la gestión de datos de la empresa y sincronización.
/// Incluye empleados, históricos, incidencias, horarios y (nuevo) lectura del
/// max_usuarios_activos de la empresa para soportar el límite de usuarios.
class AdminProvider extends ChangeNotifier {
  // Estado principal en memoria
  List<Empleado> empleados = [];
  List<Historico> historicos = [];
  List<Incidencia> incidencias = [];
  List<HorarioEmpleado> horarios = [];

  final String cifEmpresa;

  // ===== Límite de usuarios activos =====
  int? _maxUsuariosActivos; // puede ser null si el backend no lo expone o no cargó
  int? get maxUsuariosActivos => _maxUsuariosActivos;

  // Activos que "cuentan" (excluye supervisor)
  int get activosQueCuentan => empleados
      .where((e) => e.cifEmpresa == cifEmpresa && e.activo == 1 && e.rol != 'supervisor')
      .length;

  AdminProvider(this.cifEmpresa);

  // ==================== BOOT / CARGA INICIAL ====================
  Future<void> cargarDatosIniciales() async {
    // 1) Historico primero (como ya hacías)
    await sincronizarHistoricoCompleto();

    // 2) Traer empresas (para obtener max_usuarios_activos) y guardarlo local
    //    + setear _maxUsuariosActivos para esta empresa
    await _sincronizarEmpresasYLeerMax();

    // 3) Empleados (descarga -> guarda -> lee)
    await cargarEmpleados();                // por si ya hay algo local
    await sincronizarEmpleadosCompleto();   // baja remoto y vuelve a cargar

    // 4) Incidencias
    await cargarIncidencias();
    
    // 5) HORARIOS (NUEVO - necesario para el PDF)
    await cargarHorariosEmpresa(cifEmpresa);
  }

  // ==================== EMPRESAS (solo max_usuarios_activos) ====================
  /// Descarga el CSV de empresas (Code=500), hace upsert local y actualiza
  /// _maxUsuariosActivos para [cifEmpresa]. No crea servicios nuevos para mantenerlo simple.
  Future<void> _sincronizarEmpresasYLeerMax() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';
    if (token.isEmpty || baseUrl.isEmpty) {
      // Si no hay credenciales, intenta leer desde local lo que hubiera:
      _maxUsuariosActivos = await _leerMaxUsuariosDesdeLocal(cifEmpresa);
      notifyListeners();
      return;
    }

    // Code=500 -> LeoEmpresas(), tu backend devuelve CSV con cabecera:
    // "cif_empresa;nombre;direccion;telefono;codigo_postal;email;basedatos;max_usuarios_activos;"
    final url = Uri.parse('$baseUrl?Token=$token&Bd=${DatabaseConfig.databaseName}&Code=500');

    try {
      final resp = await http.get(url);
      if (resp.statusCode != 200) {
        // En caso de error de red: intenta leer local
        _maxUsuariosActivos = await _leerMaxUsuariosDesdeLocal(cifEmpresa);
        notifyListeners();
        return;
      }

      // Parse rápido del CSV y upsert en SQLite
      await _guardarEmpresasCsvLocal(resp.body);

      // Refresca el valor en memoria
      _maxUsuariosActivos = await _leerMaxUsuariosDesdeLocal(cifEmpresa);
      notifyListeners();
    } catch (e) {
      // En caso de excepción, intenta local y sigue
      _maxUsuariosActivos = await _leerMaxUsuariosDesdeLocal(cifEmpresa);
      // ignore: avoid_print
      print('[AdminProvider] Error sincronizando empresas: $e');
      notifyListeners();
    }
  }

  /// Guarda/actualiza en SQLite las empresas que vengan en el CSV.
  /// Nos interesa principalmente el campo max_usuarios_activos.
  Future<void> _guardarEmpresasCsvLocal(String csv) async {
    final db = await DatabaseHelper.instance.database;
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    // Quitar cabecera si la tiene
    final header = lines.first.trim();
    int startIdx = 0;
    if (header.toLowerCase().startsWith('cif_empresa;')) {
      startIdx = 1;
    }

    // Campo esperado en posición 7 (último) según tu PHP,
    // pero no dependemos del orden: buscamos índice por nombre en cabecera si existe.
    int idxCif = 0, idxMax = 7;
    if (startIdx == 1) {
      final cols = header.split(';');
      idxCif = cols.indexOf('cif_empresa');
      idxMax = cols.indexOf('max_usuarios_activos');
      if (idxCif < 0) idxCif = 0; // fallback
      if (idxMax < 0) idxMax = 7; // fallback
    }

    // Transacción por rendimiento/atomicidad
    await db.transaction((txn) async {
      for (int i = startIdx; i < lines.length; i++) {
        final raw = lines[i].trim();
        if (raw.isEmpty) continue;
        final parts = raw.split(';');

        // Seguro ante líneas cortas
        if (parts.isEmpty) continue;

        final cif = (idxCif < parts.length) ? parts[idxCif].trim() : '';
        if (cif.isEmpty) continue;

        // Parse del max (puede venir vacío)
        int? maxActivos;
        if (idxMax < parts.length) {
          final val = parts[idxMax].trim();
          if (val.isNotEmpty) {
            final n = int.tryParse(val);
            if (n != null) maxActivos = n;
          }
        }

        // Upsert sencillo: si existe fila, actualiza; si no, inserta.
        // No tenemos todos los campos aquí, pero no pasa nada: solo necesitamos el max_usuarios_activos.
        // Intentamos update primero:
        final updated = await txn.update(
          'empresas',
          {'max_usuarios_activos': maxActivos},
          where: 'cif_empresa = ?',
          whereArgs: [cif],
        );

        if (updated == 0) {
          // Inserta mínima si no existe
          await txn.insert('empresas', {
            'cif_empresa': cif,
            'nombre': '', // placeholders opcionales
            'direccion': null,
            'telefono': null,
            'codigo_postal': null,
            'email': null,
            'basedatos': null,
            'max_usuarios_activos': maxActivos,
          });
        }
      }
    });
  }

  /// Lee el max_usuarios_activos de SQLite para un CIF
  Future<int?> _leerMaxUsuariosDesdeLocal(String cif) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'empresas',
      columns: ['max_usuarios_activos'],
      where: 'cif_empresa = ?',
      whereArgs: [cif],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['max_usuarios_activos'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  // ==================== EMPLEADOS ====================
  Future<void> cargarEmpleados() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('empleados', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    empleados = maps.map((m) => Empleado.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> sincronizarEmpleadosCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';

    if (token.isEmpty || baseUrl.isEmpty) {
      await cargarEmpleados();
      return;
    }

    try {
      await EmpleadoService.sincronizarEmpleadosCompleto(token, baseUrl, cifEmpresa);
      await cargarEmpleados();
    } catch (e) {
      // ignore: avoid_print
      print('[AdminProvider] Error sincronizando empleados: $e');
      await cargarEmpleados(); // al menos refresca local
    }
  }

  Future<String?> addEmpleado(Empleado empleado) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final respuesta = await EmpleadoService.insertarEmpleadoRemoto(
        empleado: empleado,
        token: token,
      );
      if (respuesta['ok'] == true) {
        await sincronizarEmpleadosCompleto();
        // Tras alta, no hace falta recargar empresas; el max no cambia.
        return null;
      } else {
        return respuesta['mensaje']?.toString();
      }
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> updateEmpleado(Empleado empleado, String usuarioOriginal) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final Empleado empleadoParaEnviar =
          (empleado.passwordHash == null || empleado.passwordHash!.isEmpty)
              ? empleado.copyWith(passwordHash: null)
              : empleado;

      final respuesta = await EmpleadoService.actualizarEmpleadoRemoto(
        empleado: empleadoParaEnviar,
        usuarioOriginal: usuarioOriginal,
        token: token,
      );

      if (!respuesta.startsWith('OK')) return respuesta;
      await sincronizarEmpleadosCompleto();
      return null;
    } catch (e) {
      return 'Error actualizando empleado: $e';
    }
  }

  Future<String?> bajaEmpleado(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final empleadoActual = empleados.firstWhere(
      (e) => e.usuario == usuario,
      orElse: () => Empleado(usuario: usuario, cifEmpresa: cifEmpresa, activo: 0),
    );

    final empleadoBaja = Empleado(
      usuario: empleadoActual.usuario,
      cifEmpresa: empleadoActual.cifEmpresa,
      direccion: empleadoActual.direccion,
      poblacion: empleadoActual.poblacion,
      codigoPostal: empleadoActual.codigoPostal,
      telefono: empleadoActual.telefono,
      email: empleadoActual.email,
      nombre: empleadoActual.nombre,
      dni: empleadoActual.dni,
      rol: empleadoActual.rol,
      passwordHash: empleadoActual.passwordHash,
      puedeLocalizar: empleadoActual.puedeLocalizar,
      activo: 0,
    );

    try {
      final respuesta = await EmpleadoService.actualizarEmpleadoRemoto(
        empleado: empleadoBaja,
        usuarioOriginal: usuario,
        token: token,
      );
      if (!respuesta.startsWith('OK')) return respuesta;
      await sincronizarEmpleadosCompleto();
      return null;
    } catch (e) {
      return 'Error dando de baja empleado: $e';
    }
  }

  Future<String?> deleteEmpleado(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final respuesta = await EmpleadoService.eliminarEmpleadoRemoto(
      usuario: usuario,
      cifEmpresa: cifEmpresa,
      token: token,
    );
    if (respuesta.startsWith("OK")) {
      await sincronizarEmpleadosCompleto();
      return null;
    } else {
      return respuesta;
    }
  }

  // ==================== HISTORICO ====================
  Future<void> cargarHistoricos() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    historicos = maps.map((m) => Historico.fromMap(m)).toList();
    notifyListeners();
  }

  /// Obtiene los fichajes directamente desde la base de datos local
  /// para asegurar que se incluyan todos los campos, especialmente incidencia_codigo
  Future<List<Historico>> obtenerFichajesLocales() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'historico', 
      where: 'cif_empresa = ?', 
      whereArgs: [cifEmpresa],
      orderBy: 'fecha_entrada DESC'
    );
    return maps.map((m) => Historico.fromMap(m)).toList();
  }

  Future<void> sincronizarHistoricoCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';

    if (token.isEmpty || baseUrl.isEmpty) {
      await cargarHistoricos();
      return;
    }

    try {
      await HistoricoService.sincronizarHistoricoCompleto(token, baseUrl, cifEmpresa);
      await cargarHistoricos();
    } catch (e) {
      // ignore: avoid_print
      print('[AdminProvider] Error sincronizando histórico: $e');
      await cargarHistoricos(); // intenta al menos local
    }
  }

  // ==================== INCIDENCIAS ====================
  Future<void> cargarIncidencias() async {
    incidencias = await IncidenciaService.cargarIncidenciasLocal(cifEmpresa);
    notifyListeners();
  }

  Future<String?> addIncidencia(Incidencia incidencia) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final respuesta = await IncidenciaService.insertarIncidenciaRemoto(
      incidencia: incidencia,
      token: token,
    );
    if (respuesta.startsWith("OK")) {
      final db = await DatabaseHelper.instance.database;
      await db.insert('incidencias', incidencia.toMap());
      await cargarIncidencias();
      return null;
    } else {
      return respuesta;
    }
  }

  Future<String?> updateIncidencia(Incidencia incidencia) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final respuesta = await IncidenciaService.actualizarIncidenciaRemoto(
      incidencia: incidencia,
      token: token,
    );
    if (respuesta.startsWith("OK")) {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'incidencias',
        incidencia.toMap(),
        where: 'codigo = ? AND cif_empresa = ?',
        whereArgs: [incidencia.codigo, incidencia.cifEmpresa],
      );
      await cargarIncidencias();
      return null;
    } else {
      return respuesta;
    }
  }

  Future<String?> deleteIncidencia(String codigo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final incidencia = incidencias.firstWhere(
      (inc) => inc.codigo == codigo,
      orElse: () => Incidencia(codigo: '', cifEmpresa: ''),
    );
    final respuesta = await IncidenciaService.eliminarIncidenciaRemoto(
      codigo: codigo,
      cifEmpresa: incidencia.cifEmpresa ?? '',
      token: token,
    );
    if (respuesta.startsWith("OK")) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('incidencias', where: 'codigo = ? AND cif_empresa = ?', whereArgs: [codigo, incidencia.cifEmpresa]);
      await cargarIncidencias();
      return null;
    } else {
      return respuesta;
    }
  }

  // ==================== HORARIOS DE EMPLEADO ====================
  /// Cargar los horarios del empleado desde la API y actualiza local
  Future<void> cargarHorariosEmpleado(String dniEmpleado) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';
    try {
      await HorariosService.descargarYGuardarHorariosEmpleado(
        dniEmpleado: dniEmpleado,
        cifEmpresa: cifEmpresa,
        token: token,
        baseUrl: baseUrl,
      );
      horarios = await HorariosService.obtenerHorariosLocalPorEmpleado(
        dniEmpleado: dniEmpleado,
        cifEmpresa: cifEmpresa,
      );
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('[AdminProvider.cargarHorariosEmpleado] Error: $e');
      horarios = [];
      notifyListeners();
    }
  }

  /// Cargar todos los horarios de la empresa desde la API y actualiza local
  Future<void> cargarHorariosEmpresa(String cifEmpresa) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';
    try {
      print('[AdminProvider] Descargando horarios para empresa: $cifEmpresa');
      await HorariosService.descargarYGuardarHorariosEmpresa(
        cifEmpresa: cifEmpresa,
        token: token,
        baseUrl: baseUrl,
      );
      horarios = await HorariosService.obtenerHorariosLocalPorEmpresa(
        cifEmpresa: cifEmpresa,
      );
      print('[AdminProvider] Horarios cargados: ${horarios.length}');
      for (int i = 0; i < horarios.length; i++) {
        final h = horarios[i];
        print('[AdminProvider] Horario $i: DNI=${h.dniEmpleado}, Dia=${h.diaSemana}, Horas=${h.horasOrdinarias}, Min=${h.horasOrdinariasMin}');
      }
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('[AdminProvider.cargarHorariosEmpresa] Error: $e');
      horarios = [];
      notifyListeners();
    }
  }

  /// Añadir horario de empleado (Remoto + Local)
  Future<String?> addHorarioEmpleado(HorarioEmpleado horario) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final okRemoto = await HorariosService.insertarHorarioRemoto(
        horario: horario,
        token: token,
      );
      if (okRemoto) {
        await HorariosService.insertarHorarioLocal(horario);
        await cargarHorariosEmpresa(horario.cifEmpresa);
        return null;
      } else {
        return 'No se pudo crear el horario';
      }
    } catch (e) {
      return 'Error añadiendo horario: $e';
    }
  }

  /// ***NUEVO***: Añadir horarios masivo (varios de golpe)
  Future<String?> addHorariosEmpleadosMasivo(List<HorarioEmpleado> horariosLote) async {
    if (horariosLote.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    String? error;
    for (final horario in horariosLote) {
      final okRemoto = await HorariosService.insertarHorarioRemoto(
        horario: horario,
        token: token,
      );
      if (okRemoto) {
        await HorariosService.insertarHorarioLocal(horario);
      } else {
        error ??= 'No se pudo crear el horario para ${horario.dniEmpleado}, día ${horario.diaSemana}.';
        // Puedes decidir si abortar aquí o seguir con el resto
      }
    }
    // Recarga una sola vez tras todo el lote
    await cargarHorariosEmpresa(horariosLote.first.cifEmpresa);
    return error;
  }

  /// Actualizar horario de empleado (Remoto + Local)
  Future<String?> updateHorarioEmpleado(HorarioEmpleado horario) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final okRemoto = await HorariosService.actualizarHorarioRemoto(
        horario: horario,
        token: token,
      );
      if (okRemoto) {
        await HorariosService.actualizarHorarioLocal(horario);
        await cargarHorariosEmpresa(horario.cifEmpresa);
        return null;
      } else {
        return 'No se pudo actualizar el horario';
      }
    } catch (e) {
      return 'Error actualizando horario: $e';
    }
  }

  /// Eliminar horario de empleado (Remoto + Local)
  Future<String?> deleteHorarioEmpleado(int id, String dniEmpleado) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final okRemoto = await HorariosService.eliminarHorarioRemoto(id: id, token: token);
      if (okRemoto) {
        await HorariosService.eliminarHorarioLocal(id);
        await cargarHorariosEmpresa(cifEmpresa);
        return null;
      } else {
        return 'No se pudo eliminar el horario';
      }
    } catch (e) {
      return 'Error eliminando horario: $e';
    }
  }
}
