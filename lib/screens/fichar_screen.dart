import 'dart:async';

import 'package:fichar/screens/login_empresa_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../models/horario_empleado.dart';
import '../services/horarios_service.dart';
import '../services/historico_service.dart';
import '../services/incidencia_service.dart';

String nowToMySQL() {
  final now = DateTime.now();
  return "${now.year.toString().padLeft(4, '0')}-"
      "${now.month.toString().padLeft(2, '0')}-"
      "${now.day.toString().padLeft(2, '0')} "
      "${now.hour.toString().padLeft(2, '0')}:"
      "${now.minute.toString().padLeft(2, '0')}:"
      "${now.second.toString().padLeft(2, '0')}";
}

Future<Position?> obtenerPosicion() async {
  bool servicioActivo = await Geolocator.isLocationServiceEnabled();
  if (!servicioActivo) {
    print('El servicio de ubicación está desactivado.');
    return null;
  }

  LocationPermission permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied) {
      print('Permiso de ubicación denegado');
      return null;
    }
  }

  if (permiso == LocationPermission.deniedForever) {
    print('Permiso de ubicación denegado para siempre.');
    return null;
  }

  return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
}

class FicharScreen extends StatefulWidget {
  final bool esMultiFichaje; // <--- NUEVO
  final bool desdeLoginEmpresa; // <-- NUEVO parámetro para controlar la navegación atrás

  const FicharScreen({
    Key? key,
    this.esMultiFichaje = false,
    this.desdeLoginEmpresa = false,
  }) : super(key: key);

  @override
  State<FicharScreen> createState() => _FicharScreenState();
}

class _FicharScreenState extends State<FicharScreen> {
  final TextEditingController txtObservaciones = TextEditingController();

  bool entradaHabilitada = true;
  bool salidaHabilitada = true;

  bool _entradaEnProceso = false;
  bool _salidaEnProceso = false;

  bool _loading = false;

  late String cifEmpresa;
  late String token;
  late String usuario;
  late String nombreEmpleado;
  late String dniEmpleado;
  late String idSucursal;
  String vaUltimaAccion = '';

  int puedeLocalizar = 0;

  final ValueNotifier<Duration> _tiempoTrabajadoNotifier = ValueNotifier(Duration.zero);
  DateTime? _horaEntrada;
  Timer? _timer;

  List<Incidencia> listaIncidencias = [];
  bool cargandoIncidencias = false;
  String? errorIncidencias;

  List<HorarioEmpleado> _tramosHoy = [];
  bool _cargandoHorarios = true;

  Timer? _timerSalidaMultiFichaje;

  String _keyUltimaAccion(String usuario, String cifEmpresa) =>
      'ultimo_tipo_fichaje_${usuario}_$cifEmpresa';

  String _keyHoraEntrada(String usuario, String cifEmpresa) =>
      'hora_entrada_${usuario}_$cifEmpresa';

  @override
  void initState() {
    super.initState();
    print('[DEBUG] FicharScreen initState disparado');
    _loadConfig().then((_) {
      _cargarHorariosDeHoy();
    });
  }

  @override
  void dispose() {
    txtObservaciones.dispose();
    _timer?.cancel();
    _tiempoTrabajadoNotifier.dispose();
    _timerSalidaMultiFichaje?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    cifEmpresa = prefs.getString('cif_empresa') ?? '';
    token = prefs.getString('token') ?? '';
    usuario = prefs.getString('usuario') ?? '';
    nombreEmpleado = prefs.getString('nombre_empleado') ?? '';
    dniEmpleado = prefs.getString('dni_empleado') ?? '';
    idSucursal = prefs.getString('id_sucursal') ?? '';
    vaUltimaAccion = prefs.getString(_keyUltimaAccion(usuario, cifEmpresa)) ?? '';
    final horaEntradaStr = prefs.getString(_keyHoraEntrada(usuario, cifEmpresa));
    puedeLocalizar = prefs.getInt('puede_localizar') ?? 0;

    if (horaEntradaStr != null && horaEntradaStr.isNotEmpty) {
      _horaEntrada = DateTime.tryParse(horaEntradaStr);
    } else {
      _horaEntrada = null;
    }

    _calcularEstadoBotones();
    _initTemporizador();
  }

  Future<void> _cargarHorariosDeHoy() async {
    setState(() {
      _cargandoHorarios = true;
    });
    try {
      final todosHorarios = await HorariosService.obtenerHorariosLocalPorEmpleado(
        dniEmpleado: dniEmpleado,
        cifEmpresa: cifEmpresa,
      );
      final hoy = DateTime.now();
      final diaSemana = (hoy.weekday - 1) % 7;

      setState(() {
        _tramosHoy = todosHorarios.where((h) => h.diaSemana == diaSemana).toList();
        _cargandoHorarios = false;
      });
    } catch (e) {
      print('Error cargando horarios de hoy: $e');
      setState(() {
        _tramosHoy = [];
        _cargandoHorarios = false;
      });
    }
  }

  void _calcularEstadoBotones() {
    print('[DEBUG] vaUltimaAccion al calcular: $vaUltimaAccion');
    entradaHabilitada = vaUltimaAccion != 'Entrada';
    salidaHabilitada = vaUltimaAccion == 'Entrada';
    setState(() {});
  }

  void _initTemporizador() {
    _timer?.cancel();

    if (vaUltimaAccion == 'Entrada' && _horaEntrada != null) {
      _actualizarTiempoTrabajado();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _actualizarTiempoTrabajado();
      });
    } else {
      _tiempoTrabajadoNotifier.value = Duration.zero;
    }
  }

  void _actualizarTiempoTrabajado() {
    if (_horaEntrada == null) return;
    final ahora = DateTime.now();
    final diferencia = ahora.difference(_horaEntrada!);
    if (_tiempoTrabajadoNotifier.value.inSeconds != diferencia.inSeconds) {
      _tiempoTrabajadoNotifier.value = diferencia;
    }
  }

  Future<void> _setUltimaAccion(String tipo, {DateTime? horaEntrada}) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyUltimaAccion(usuario, cifEmpresa), tipo);

    if (tipo == 'Entrada' && horaEntrada != null) {
      await prefs.setString(_keyHoraEntrada(usuario, cifEmpresa), horaEntrada.toIso8601String());
      _horaEntrada = horaEntrada;
    }

    if (tipo == 'Salida' || (tipo.startsWith('Incidencia') && tipo != 'IncidenciaSolo')) {
      await prefs.remove(_keyHoraEntrada(usuario, cifEmpresa));
      _horaEntrada = null;
    }

    vaUltimaAccion = tipo;
    _calcularEstadoBotones();
    _initTemporizador();
    setState(() {});
  }

  // --- Modo Multi-Fichaje: salir tras 5s ---
  void _autoSalirTrasFichajeExitoso() {
    if (!widget.esMultiFichaje) return;
    _timerSalidaMultiFichaje?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fichaje realizado, volviendo a pantalla de inicio...')),
    );
    _timerSalidaMultiFichaje = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmpresaLoginScreen()),
          (route) => false,
        );
      }
    });
  }

  Future<void> _registrarFichaje(
    String tipo, {
    String? incidenciaCodigo,
    String? observaciones,
    bool esIncidencia = false,
  }) async {
    // Debug: verificar los parámetros recibidos
    print('🔍 DEBUG _registrarFichaje:');
    print('   tipo: $tipo');
    print('   incidenciaCodigo: $incidenciaCodigo');
    print('   observaciones: $observaciones');
    print('   esIncidencia: $esIncidencia');
    
    final fechaActual = nowToMySQL();
    final ahora = DateTime.now();

    String tipoParaGuardar = tipo;
    if (esIncidencia) {
      if (tipo == 'IncidenciaSolo') {
        tipoParaGuardar = 'IncidenciaSolo';
      } else {
        if (vaUltimaAccion == 'Entrada') {
          tipoParaGuardar = 'IncidenciaEntrada';
        } else if (vaUltimaAccion == 'Salida') {
          tipoParaGuardar = 'IncidenciaSalida';
        } else {
          tipoParaGuardar = 'IncidenciaSinContexto';
        }
      }
    }

    Position? pos;
    if (puedeLocalizar == 1) {
      pos = await obtenerPosicion();
    } else {
      pos = null;
    }

    final uuid = Uuid();
    final String uuidFichaje = uuid.v4();

    final historico = Historico(
      id: 0,
      uuid: uuidFichaje,
      cifEmpresa: cifEmpresa,
      usuario: usuario,
      fechaEntrada: tipo == 'Salida' ? '' : fechaActual,
      fechaSalida: tipo == 'Salida' ? fechaActual : null,
      tipo: tipoParaGuardar,
      incidenciaCodigo: incidenciaCodigo,
      observaciones: observaciones,
      nombreEmpleado: nombreEmpleado,
      dniEmpleado: dniEmpleado,
      idSucursal: idSucursal,
      latitud: pos?.latitude,
      longitud: pos?.longitude,
    );
    
    // Debug: verificar el objeto Historico creado
    print('🔍 DEBUG Historico creado:');
    print('   incidenciaCodigo: ${historico.incidenciaCodigo}');
    print('   tipo: ${historico.tipo}');
    print('   observaciones: ${historico.observaciones}');
    print('   uuid: ${historico.uuid}');

    await HistoricoService.guardarFichajeLocal(historico);

    try {
      await HistoricoService.guardarFichajeRemoto(
        historico,
        token,
        BASE_URL,
        'qame400',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tipoParaGuardar registrada (online)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tipoParaGuardar guardada localmente')),
      );
    }

    if (tipo == 'Entrada') {
      await _setUltimaAccion(tipo, horaEntrada: ahora);
    } else if (tipo != 'IncidenciaSolo') {
      await _setUltimaAccion(tipoParaGuardar);
    }

    _autoSalirTrasFichajeExitoso();
  }

  Future<void> _procesarFichajeConLoading(Future<void> Function() funcion) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await funcion();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onEntrada() {
    print('[DEBUG] _onEntrada llamado');
    if (_entradaEnProceso) return;
    _entradaEnProceso = true;
    _procesarFichajeConLoading(() => _registrarFichaje('Entrada')).then((_) {
      _entradaEnProceso = false;
    });
  }

  void _onSalida() {
    print('[DEBUG] _onSalida llamado');
    if (_salidaEnProceso) return;
    _salidaEnProceso = true;
    _procesarFichajeConLoading(() => _registrarFichaje('Salida')).then((_) {
      _salidaEnProceso = false;
    });
  }

  bool puedeFicharAhora() {
    if (_cargandoHorarios) return false;
    if (_tramosHoy.isEmpty) return true;
    final ahora = TimeOfDay.now();
    for (final tramo in _tramosHoy) {
      final inicio = _parseTime(tramo.horaInicio);
      final margenAntes = tramo.margenEntradaAntes;
      final margenDespues = tramo.margenEntradaDespues ?? 0;
      final minutosInicio = inicio.hour * 60 + inicio.minute - margenAntes;
      final minutosFin = inicio.hour * 60 + inicio.minute + margenDespues;
      final minutosAhora = ahora.hour * 60 + ahora.minute;
      if (minutosAhora >= minutosInicio && minutosAhora <= minutosFin) {
        return true;
      }
    }
    return false;
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _cargarIncidencias() async {
    setState(() {
      cargandoIncidencias = true;
      errorIncidencias = null;
    });
    try {
      await IncidenciaService.descargarYGuardarIncidencias(cifEmpresa, token, BASE_URL);
      listaIncidencias = await IncidenciaService.cargarIncidenciasLocal(cifEmpresa);
    } catch (e) {
      try {
        listaIncidencias = await IncidenciaService.cargarIncidenciasLocal(cifEmpresa);
        errorIncidencias = 'Mostrando incidencias offline';
      } catch (_) {
        listaIncidencias = [];
        errorIncidencias = 'No se pueden cargar incidencias.';
      }
    }
    setState(() {
      cargandoIncidencias = false;
    });
  }

  void _onIncidencia() async {
    if (_loading) return;
    await _cargarIncidencias();
    txtObservaciones.clear();
    Incidencia? seleccionada;
    bool confirmado = false;
    bool _procesandoIncidencia = false;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Registrar incidencia',
                        style: TextStyle(fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      cargandoIncidencias
                          ? const CircularProgressIndicator()
                          : DropdownButtonFormField<Incidencia>(
                              value: seleccionada,
                              items: listaIncidencias
                                  .map((inc) => DropdownMenuItem(
                                        value: inc,
                                        child: Text(inc.descripcion ?? inc.codigo),
                                      ))
                                  .toList(),
                              onChanged: (valor) => setStateDialog(() => seleccionada = valor),
                              decoration: const InputDecoration(
                                labelText: 'Tipo de incidencia',
                                border: OutlineInputBorder(),
                              ),
                            ),
                      if (errorIncidencias != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(errorIncidencias!, style: const TextStyle(color: Colors.orange)),
                        ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: txtObservaciones,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      CheckboxListTile(
                        value: confirmado,
                        onChanged: (v) => setStateDialog(() => confirmado = v ?? false),
                        title: const Text('Confirmo la incidencia'),
                        activeColor: Colors.blue,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Cancelar', style: TextStyle(color: Colors.blue)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            ),
                            child: const Text('Registrar solo incidencia'),
                            onPressed: (seleccionada != null && confirmado && !_procesandoIncidencia)
                                ? () async {
                                    setStateDialog(() => _procesandoIncidencia = true);
                                    try {
                                      // Debug: verificar qué se está pasando
                                      print('🔍 DEBUG Registrar IncidenciaSolo:');
                                      print('   seleccionada: $seleccionada');
                                      print('   seleccionada!.codigo: ${seleccionada!.codigo}');
                                      print('   seleccionada!.descripcion: ${seleccionada!.descripcion}');
                                      print('   observaciones: ${txtObservaciones.text.trim()}');
                                      
                                      await _registrarFichaje(
                                        'IncidenciaSolo',
                                        incidenciaCodigo: seleccionada!.codigo,
                                        observaciones: txtObservaciones.text.trim(),
                                        esIncidencia: true,
                                      );
                                      Navigator.pop(ctx);
                                    } catch (e) {
                                      setStateDialog(() => _procesandoIncidencia = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al registrar incidencia: $e')),
                                      );
                                    }
                                  }
                                : null,
                          ),
                          if (vaUltimaAccion == 'Entrada')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              ),
                              child: const Text('Registrar y salir'),
                              onPressed: (seleccionada != null && confirmado && !_procesandoIncidencia)
                                  ? () async {
                                      setStateDialog(() => _procesandoIncidencia = true);
                                      try {
                                        await _registrarFichaje(
                                          'Incidencia',
                                          incidenciaCodigo: seleccionada!.codigo,
                                          observaciones: txtObservaciones.text.trim(),
                                          esIncidencia: true,
                                        );
                                        await _registrarFichaje('Salida');
                                        Navigator.pop(ctx);
                                      } catch (e) {
                                        setStateDialog(() => _procesandoIncidencia = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error al registrar incidencia o salida: $e')),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          if (vaUltimaAccion != 'Entrada')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              ),
                              child: const Text('Registrar y entrar'),
                              onPressed: (seleccionada != null && confirmado && !_procesandoIncidencia)
                                  ? () async {
                                      setStateDialog(() => _procesandoIncidencia = true);
                                      try {
                                        await _registrarFichaje(
                                          'Incidencia',
                                          incidenciaCodigo: seleccionada!.codigo,
                                          observaciones: txtObservaciones.text.trim(),
                                          esIncidencia: true,
                                        );
                                        await _registrarFichaje('Entrada');
                                        Navigator.pop(ctx);
                                      } catch (e) {
                                        setStateDialog(() => _procesandoIncidencia = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error al registrar incidencia o entrada: $e')),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _temporizadorWidget() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _tiempoTrabajadoNotifier,
      builder: (_, duracion, __) {
        if (vaUltimaAccion != 'Entrada' || _horaEntrada == null) return const SizedBox.shrink();
        String dosCifras(int n) => n.toString().padLeft(2, '0');
        final horas = dosCifras(duracion.inHours);
        final minutos = dosCifras(duracion.inMinutes.remainder(60));
        final segundos = dosCifras(duracion.inSeconds.remainder(60));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              const Text("Tiempo trabajado hoy:",
                  style: TextStyle(fontSize: 17, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              Text("$horas:$minutos:$segundos",
                  style: const TextStyle(fontSize: 28, color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        leading: widget.desdeLoginEmpresa
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.blue),
                tooltip: 'Volver',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const EmpresaLoginScreen()),
                    (route) => false,
                  );
                },
              )
            : null,
        title: const Text('Fichar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              width: ancho > 400 ? 400 : ancho * 0.97,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 7))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.work_history, size: 54, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text('¿Qué quieres hacer?',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 15),
                  _temporizadorWidget(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Fichar entrada'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: (entradaHabilitada && !_entradaEnProceso && puedeFicharAhora() && !_loading)
                          ? _onEntrada
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Fichar salida'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: (salidaHabilitada && !_salidaEnProceso && !_loading) ? _onSalida : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Registrar incidencia'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: !_loading ? _onIncidencia : null,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (vaUltimaAccion.isNotEmpty)
                    Text(
                      'Última acción: $vaUltimaAccion',
                      style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                    ),
                ],
              ),
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
