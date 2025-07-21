import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart'; 
import '../models/historico.dart'; 
import '../models/incidencia.dart'; 
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
  const FicharScreen({Key? key}) : super(key: key);

  @override
  State<FicharScreen> createState() => _FicharScreenState();
}

class _FicharScreenState extends State<FicharScreen> {
  final TextEditingController txtObservaciones = TextEditingController();

  bool entradaHabilitada = true;
  bool salidaHabilitada = true;

  late String cifEmpresa;
  late String token;
  late String usuario;
  late String nombreEmpleado;
  late String dniEmpleado;
  late String idSucursal;
  String vaUltimaAccion = '';

  final ValueNotifier<Duration> _tiempoTrabajadoNotifier = ValueNotifier(Duration.zero);
  DateTime? _horaEntrada;
  Timer? _timer;

  List<Incidencia> listaIncidencias = [];
  bool cargandoIncidencias = false;
  String? errorIncidencias;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    final nuevaCifEmpresa     = prefs.getString('cif_empresa')     ?? '';
    final nuevoToken          = prefs.getString('token')           ?? '';
    final nuevoUsuario        = prefs.getString('usuario')         ?? '';
    final nuevoNombreEmpleado = prefs.getString('nombre_empleado') ?? '';
    final nuevoDniEmpleado    = prefs.getString('dni_empleado')    ?? '';
    final nuevoIdSucursal     = prefs.getString('id_sucursal')     ?? '';
    final nuevaUltimaAccion   = prefs.getString('ultimo_tipo_fichaje') ?? '';
    final horaEntradaStr = prefs.getString('hora_entrada');

    DateTime? nuevaHoraEntrada;
    if (horaEntradaStr != null && horaEntradaStr.isNotEmpty) {
      nuevaHoraEntrada = DateTime.tryParse(horaEntradaStr);
    }

    setState(() {
      cifEmpresa = nuevaCifEmpresa;
      token = nuevoToken;
      usuario = nuevoUsuario;
      nombreEmpleado = nuevoNombreEmpleado;
      dniEmpleado = nuevoDniEmpleado;
      idSucursal = nuevoIdSucursal;
      vaUltimaAccion = nuevaUltimaAccion;
      _horaEntrada = nuevaHoraEntrada;
    });

    _calcularEstadoBotones();
    _initTemporizador();
  }

  void _calcularEstadoBotones() {
    final nuevaEntradaHabilitada = vaUltimaAccion != 'Entrada';
    final nuevaSalidaHabilitada = vaUltimaAccion == 'Entrada';
    setState(() {
      entradaHabilitada = nuevaEntradaHabilitada;
      salidaHabilitada = nuevaSalidaHabilitada;
    });
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

    await prefs.setString('ultimo_tipo_fichaje', tipo);

    if (tipo == 'Entrada' && horaEntrada != null) {
      await prefs.setString('hora_entrada', horaEntrada.toIso8601String());
      _horaEntrada = horaEntrada;
    }

    // Solo borramos hora_entrada si es Salida o incidencia que NO sea "IncidenciaSolo"
    if (tipo == 'Salida' || (tipo.startsWith('Incidencia') && tipo != 'IncidenciaSolo')) {
      await prefs.remove('hora_entrada');
      _horaEntrada = null;
    }

    setState(() => vaUltimaAccion = tipo);
    _calcularEstadoBotones();
    _initTemporizador();
  }

  Future<void> _registrarFichaje(
    String tipo, {
    String? incidenciaCodigo,
    String? observaciones,
    bool esIncidencia = false,
  }) async {
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

    Position? pos = await obtenerPosicion();

    final historico = Historico(
      id: 0,
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
    // NO actualizamos ni cerramos fichaje si es IncidenciaSolo
  }

  void _onEntrada() => _registrarFichaje('Entrada');
  void _onSalida() => _registrarFichaje('Salida');

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
    await _cargarIncidencias();
    txtObservaciones.clear();
    Incidencia? seleccionada;
    bool confirmado = false;

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
                            onPressed: (seleccionada != null && confirmado)
                                ? () {
                                    Navigator.pop(ctx);
                                    _registrarFichaje(
                                      'IncidenciaSolo',
                                      incidenciaCodigo: seleccionada!.codigo,
                                      observaciones: txtObservaciones.text.trim(),
                                      esIncidencia: true,
                                    );
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
                              onPressed: (seleccionada != null && confirmado)
                                  ? () async {
                                      Navigator.pop(ctx);
                                      await _registrarFichaje(
                                        'Incidencia',
                                        incidenciaCodigo: seleccionada!.codigo,
                                        observaciones: txtObservaciones.text.trim(),
                                        esIncidencia: true,
                                      );
                                      await _registrarFichaje('Salida');
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
                              onPressed: (seleccionada != null && confirmado)
                                  ? () async {
                                      Navigator.pop(ctx);
                                      await _registrarFichaje(
                                        'Incidencia',
                                        incidenciaCodigo: seleccionada!.codigo,
                                        observaciones: txtObservaciones.text.trim(),
                                        esIncidencia: true,
                                      );
                                      await _registrarFichaje('Entrada');
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
  void dispose() {
    txtObservaciones.dispose();
    _timer?.cancel();
    _tiempoTrabajadoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          width: ancho > 400 ? 400 : ancho * 0.97,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [ BoxShadow(color: Colors.blue.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 7)) ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.work, size: 54, color: Colors.blue),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: entradaHabilitada ? _onEntrada : null,
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Fichar salida'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: salidaHabilitada ? _onSalida : null,
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
                  onPressed: _onIncidencia,
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
    );
  }
}
