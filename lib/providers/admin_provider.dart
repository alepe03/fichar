import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/empleado.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../db/database_helper.dart';
import '../services/empleado_service.dart';
import '../services/incidencia_service.dart';
import '../services/historico_service.dart';  // Importar el servicio

class AdminProvider extends ChangeNotifier {
  List<Empleado> empleados = [];
  List<Historico> historicos = [];
  List<Incidencia> incidencias = [];

  final String cifEmpresa;

  AdminProvider(this.cifEmpresa);

  /// Carga empleados de la base local
  Future<void> cargarEmpleados() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('empleados', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    empleados = maps.map((m) => Empleado.fromMap(m)).toList();
    notifyListeners();
  }

  /// Carga históricos de la base local
  Future<void> cargarHistoricos() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    historicos = maps.map((m) => Historico.fromMap(m)).toList();
    notifyListeners();
  }

  /// Carga incidencias de la base local
  Future<void> cargarIncidencias() async {
    incidencias = await IncidenciaService.cargarIncidenciasLocal(cifEmpresa);
    notifyListeners();
  }

  /// Sincroniza el histórico completo desde el servidor y actualiza local
  Future<void> sincronizarHistoricoCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = prefs.getString('baseUrl') ?? ''; // Asumo guardas la url base en prefs
    final nombreBD = cifEmpresa; // Usas cifEmpresa como base de datos o parámetro

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

  /// Llama a la sincronización y carga los datos iniciales
  Future<void> cargarDatosIniciales() async {
    print('[AdminProvider] Inicio cargarDatosIniciales');
    await sincronizarHistoricoCompleto();
    await cargarEmpleados();
    await cargarIncidencias();
    print('[AdminProvider] Fin cargarDatosIniciales');
  }

  // Métodos para manejar empleados e incidencias (add/update/delete) sin cambios
  Future<String?> addEmpleado(Empleado empleado) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final respuesta = await EmpleadoService.insertarEmpleadoRemoto(empleado: empleado, token: token);
    if (respuesta.startsWith("OK")) {
      final db = await DatabaseHelper.instance.database;
      await db.insert('empleados', empleado.toMap());
      await cargarEmpleados();
      return null;
    } else {
      return respuesta;
    }
  }

  Future<String?> updateEmpleado(Empleado empleado, String usuarioOriginal) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final respuesta = await EmpleadoService.actualizarEmpleadoRemoto(
        empleado: empleado,
        usuarioOriginal: usuarioOriginal,
        token: token,
      );

      if (!respuesta.startsWith('OK')) {
        return respuesta;
      }

      final db = await DatabaseHelper.instance.database;

      final registros = await db.query(
        'empleados',
        where: 'usuario = ? AND cif_empresa = ?',
        whereArgs: [usuarioOriginal, empleado.cifEmpresa],
      );

      if (registros.isEmpty) {
        return 'No existe registro con usuario $usuarioOriginal y empresa ${empleado.cifEmpresa}';
      }

      final count = await db.update(
        'empleados',
        empleado.toMap(),
        where: 'usuario = ? AND cif_empresa = ?',
        whereArgs: [usuarioOriginal, empleado.cifEmpresa],
      );

      if (count == 0) {
        return 'No se encontró el registro o no hubo cambios';
      }

      await cargarEmpleados();
      return null;
    } catch (e) {
      return 'Error actualizando empleado: $e';
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
      final db = await DatabaseHelper.instance.database;
      await db.delete('empleados', where: 'usuario = ? AND cif_empresa = ?', whereArgs: [usuario, cifEmpresa]);
      await cargarEmpleados();
      return null;
    } else {
      return respuesta;
    }
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
}
