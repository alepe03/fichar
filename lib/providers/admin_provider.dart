import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/empleado.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../models/horario_empleado.dart';

import '../db/database_helper.dart';
import '../services/empleado_service.dart';
import '../services/incidencia_service.dart';
import '../services/historico_service.dart';
import '../services/horarios_service.dart';

/// Provider principal para la gestión de datos de la empresa y sincronización.
/// Incluye empleados, históricos, incidencias y horarios.
class AdminProvider extends ChangeNotifier {
  List<Empleado> empleados = [];
  List<Historico> historicos = [];
  List<Incidencia> incidencias = [];
  List<HorarioEmpleado> horarios = [];

  final String cifEmpresa;

  AdminProvider(this.cifEmpresa);

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

    if (token.isEmpty || baseUrl.isEmpty) return;

    try {
      await EmpleadoService.sincronizarEmpleadosCompleto(token, baseUrl, cifEmpresa);
      await cargarEmpleados();
    } catch (e) {
      print('[AdminProvider] Error sincronizando empleados: $e');
    }
  }

  Future<void> cargarHistoricos() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    historicos = maps.map((m) => Historico.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> cargarIncidencias() async {
    incidencias = await IncidenciaService.cargarIncidenciasLocal(cifEmpresa);
    notifyListeners();
  }

  Future<void> sincronizarHistoricoCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';

    if (token.isEmpty || baseUrl.isEmpty) return;

    try {
      await HistoricoService.sincronizarHistoricoCompleto(token, baseUrl, cifEmpresa);
      await cargarHistoricos();
    } catch (e) {
      print('[AdminProvider] Error sincronizando histórico: $e');
    }
  }

  Future<void> cargarDatosIniciales() async {
    await sincronizarHistoricoCompleto();
    await cargarEmpleados();
    await cargarIncidencias();
  }

  Future<String?> addEmpleado(Empleado empleado) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      final respuesta = await EmpleadoService.insertarEmpleadoRemoto(
        empleado: empleado,
        token: token,
      );
      if (respuesta.startsWith("OK")) {
        await sincronizarEmpleadosCompleto();
        return null;
      } else {
        return respuesta;
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

  // ==================== INCIDENCIAS ====================
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
      await HorariosService.descargarYGuardarHorariosEmpresa(
        cifEmpresa: cifEmpresa,
        token: token,
        baseUrl: baseUrl,
      );
      horarios = await HorariosService.obtenerHorariosLocalPorEmpresa(
        cifEmpresa: cifEmpresa,
      );
      notifyListeners();
    } catch (e) {
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
        // Puedes elegir si seguir o abortar aquí, según política de UX
      }
    }
    // Recarga sólo una vez tras todo el lote
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
