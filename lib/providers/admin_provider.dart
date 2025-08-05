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
/// Todos los métodos que modifican datos sincronizan con el backend y la base local.
class AdminProvider extends ChangeNotifier {
  List<Empleado> empleados = [];         // Lista de empleados de la empresa
  List<Historico> historicos = [];       // Lista de fichajes/históricos
  List<Incidencia> incidencias = [];     // Lista de incidencias
  List<HorarioEmpleado> horarios = [];   // Lista de horarios de empleados

  final String cifEmpresa;               // CIF de la empresa gestionada

  AdminProvider(this.cifEmpresa);

  // ==================== EMPLEADOS ====================

  /// Carga los empleados de la base de datos local
  Future<void> cargarEmpleados() async {
    final db = await DatabaseHelper.instance.database;
    final maps =
        await db.query('empleados', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    empleados = maps.map((m) => Empleado.fromMap(m)).toList();
    notifyListeners();
  }

  /// Sincroniza todos los empleados con el backend y recarga local
  Future<void> sincronizarEmpleadosCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';

    if (token.isEmpty || baseUrl.isEmpty) {
      print('[AdminProvider.sincronizarEmpleadosCompleto] Token o baseUrl no configurados');
      return;
    }

    try {
      print('[AdminProvider.sincronizarEmpleadosCompleto] Iniciando sincronización completa de empleados...');
      await EmpleadoService.sincronizarEmpleadosCompleto(token, baseUrl, cifEmpresa);
      await cargarEmpleados();
      print('[AdminProvider.sincronizarEmpleadosCompleto] Sincronización completa de empleados finalizada');
    } catch (e) {
      print('[AdminProvider.sincronizarEmpleadosCompleto] Error sincronizando empleados: $e');
    }
  }

  /// Carga los fichajes/históricos de la base de datos local
  Future<void> cargarHistoricos() async {
    final db = await DatabaseHelper.instance.database;
    final maps =
        await db.query('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    historicos = maps.map((m) => Historico.fromMap(m)).toList();
    notifyListeners();
  }

  /// Carga las incidencias de la base de datos local
  Future<void> cargarIncidencias() async {
    incidencias = await IncidenciaService.cargarIncidenciasLocal(cifEmpresa);
    notifyListeners();
  }

  /// Sincroniza todos los fichajes/históricos con el backend y recarga local
  Future<void> sincronizarHistoricoCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? '';
    final nombreBD = cifEmpresa;

    if (token.isEmpty || baseUrl.isEmpty) {
      print('[AdminProvider.sincronizarHistoricoCompleto] Token o baseUrl no configurados');
      return;
    }

    try {
      print('[AdminProvider.sincronizarHistoricoCompleto] Iniciando sincronización...');
      await HistoricoService.sincronizarHistoricoCompleto(token, baseUrl, nombreBD);
      await cargarHistoricos();
      print('[AdminProvider.sincronizarHistoricoCompleto] Sincronización completada');
    } catch (e) {
      print('[AdminProvider.sincronizarHistoricoCompleto] Error sincronizando histórico: $e');
    }
  }

  /// Carga todos los datos iniciales (histórico, empleados, incidencias)
  Future<void> cargarDatosIniciales() async {
    print('[AdminProvider] Inicio cargarDatosIniciales');
    await sincronizarHistoricoCompleto();
    await cargarEmpleados();
    await cargarIncidencias();
    print('[AdminProvider] Fin cargarDatosIniciales');
  }

  /// Añade un empleado (remoto y local)
  Future<String?> addEmpleado(Empleado empleado) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final respuesta = await EmpleadoService.insertarEmpleadoRemoto(
        empleado: empleado,
        token: token,
      );

      if (respuesta.startsWith("OK")) {
        // Sincronizar todos los empleados tras añadir
        await sincronizarEmpleadosCompleto();
        return null;
      } else {
        return respuesta;
      }
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Actualiza un empleado (remoto y local)
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

      if (!respuesta.startsWith('OK')) {
        return respuesta;
      }

      // Sincronizar todos los empleados tras actualizar
      await sincronizarEmpleadosCompleto();

      return null;
    } catch (e) {
      return 'Error actualizando empleado: $e';
    }
  }

  /// Da de baja a un empleado (remoto y local)
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

      if (!respuesta.startsWith('OK')) {
        return respuesta;
      }

      // Sincronizar todos los empleados tras dar de baja
      await sincronizarEmpleadosCompleto();

      return null;
    } catch (e) {
      return 'Error dando de baja empleado: $e';
    }
  }

  /// Elimina un empleado (remoto y local)
  Future<String?> deleteEmpleado(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final respuesta = await EmpleadoService.eliminarEmpleadoRemoto(
      usuario: usuario,
      cifEmpresa: cifEmpresa,
      token: token,
    );
    if (respuesta.startsWith("OK")) {
      // Sincronizar todos los empleados tras borrar
      await sincronizarEmpleadosCompleto();
      return null;
    } else {
      return respuesta;
    }
  }

  // ==================== INCIDENCIAS ====================

  /// Añade una incidencia (remoto y local)
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

  /// Actualiza una incidencia (remoto y local)
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

  /// Elimina una incidencia (remoto y local)
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
      // 1. Descarga y guarda los horarios desde API en SQLite
      await HorariosService.descargarYGuardarHorariosEmpleado(
        dniEmpleado: dniEmpleado,
        cifEmpresa: cifEmpresa,
        token: token,
        baseUrl: baseUrl,
      );
      // 2. Cárgalos de local
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
      // 1. Descarga y guarda TODOS los horarios desde API en SQLite
      await HorariosService.descargarYGuardarHorariosEmpresa(
        cifEmpresa: cifEmpresa,
        token: token,
        baseUrl: baseUrl,
      );
      // 2. Cárgalos de local
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
  /// Añade un horario tanto en el servidor remoto como en la base de datos local.
  /// Si la inserción remota es exitosa, también inserta localmente y recarga los horarios de la empresa.
  /// Devuelve null si todo va bien, o un mensaje de error si falla.
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

  /// Actualizar horario de empleado (Remoto + Local)
  /// Actualiza un horario tanto en el servidor remoto como en la base de datos local.
  /// Si la actualización remota es exitosa, también actualiza localmente y recarga los horarios de la empresa.
  /// Devuelve null si todo va bien, o un mensaje de error si falla.
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
  /// Elimina un horario tanto en el servidor remoto como en la base de datos local.
  /// Si la eliminación remota es exitosa, también elimina localmente y recarga los horarios de la empresa.
  /// Devuelve null si todo va bien, o un mensaje de error si falla.
  Future<String?> deleteHorarioEmpleado(int id, String dniEmpleado) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    try {
      // Llama al servicio remoto para eliminar el horario en el backend
      final okRemoto = await HorariosService.eliminarHorarioRemoto(id: id, token: token);
      if (okRemoto) {
        // Si se elimina correctamente en remoto, elimina también en local
        await HorariosService.eliminarHorarioLocal(id);
        // Recarga los horarios de la empresa para actualizar la vista
        await cargarHorariosEmpresa(cifEmpresa);
        return null;
      } else {
        // Si falla la eliminación remota, devuelve mensaje de error
        return 'No se pudo eliminar el horario';
      }
    } catch (e) {
      // Si ocurre una excepción, devuelve el error formateado
      return 'Error eliminando horario: $e';
    }
  }
}
