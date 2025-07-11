import 'package:flutter/material.dart';
import '../models/historico.dart';
import '../services/historico_service.dart';

// --------- MODELOS DE AGRUPADO ---------
class SesionTrabajo {
  final Historico? entrada;
  final Historico? salida;
  final List<IncidenciaEnSesion> incidencias;
  SesionTrabajo({
    required this.entrada,
    required this.salida,
    required this.incidencias,
  });
}

class IncidenciaEnSesion {
  final Historico incidencia;
  String contexto; // "Entrada", "Salida" o "Sin entrada/salida"
  IncidenciaEnSesion(this.incidencia, this.contexto);
}

// --------- WIDGET PRINCIPAL ---------
class HistoricoScreen extends StatefulWidget {
  final String usuario;
  final String cifEmpresa;

  const HistoricoScreen({Key? key, required this.usuario, required this.cifEmpresa}) : super(key: key);

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Historico> registros = [];
  bool cargando = true;
  String? errorMsg;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    setState(() {
      cargando = true;
      errorMsg = null;
    });
    try {
      final all = await HistoricoService.obtenerFichajesUsuario(widget.usuario, widget.cifEmpresa);
      registros = all.where((h) {
        String? fecha = (h.tipo == 'Salida') ? h.fechaSalida : h.fechaEntrada;
        if (fecha == null || fecha.isEmpty) return false;
        final dt = DateTime.tryParse(fecha);
        return dt != null && dt.year == _selectedYear && dt.month == _selectedMonth;
      }).toList();

      // Ordena por fecha relevante ascendente para agrupar bien
      registros.sort((a, b) {
        final fechaA = (a.tipo == 'Salida' ? a.fechaSalida : a.fechaEntrada) ?? '';
        final fechaB = (b.tipo == 'Salida' ? b.fechaSalida : b.fechaEntrada) ?? '';
        final dtA = DateTime.tryParse(fechaA) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse(fechaB) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtA.compareTo(dtB);
      });
    } catch (e) {
      errorMsg = 'Error cargando registros: $e';
    }
    setState(() {
      cargando = false;
    });
  }

  List<DropdownMenuItem<int>> _buildYears() {
    final now = DateTime.now();
    final years = List.generate(6, (i) => now.year - i);
    return years.map((y) => DropdownMenuItem<int>(value: y, child: Text('$y'))).toList();
  }

  List<DropdownMenuItem<int>> _buildMonths() {
    return List.generate(12, (i) => i + 1)
        .map((m) => DropdownMenuItem<int>(
              value: m,
              child: Text('${m.toString().padLeft(2, '0')}'),
            ))
        .toList();
  }

  // -------- AGRUPADOR MEJORADO --------
  List<SesionTrabajo> _agruparSesiones(List<Historico> registros) {
    List<SesionTrabajo> sesiones = [];
    Historico? entradaPendiente;
    List<IncidenciaEnSesion> incidenciasPendientes = [];

    for (final reg in registros) {
      if (reg.tipo == 'Entrada') {
        if (entradaPendiente != null) {
          sesiones.add(SesionTrabajo(
            entrada: entradaPendiente,
            salida: null,
            incidencias: List.of(incidenciasPendientes),
          ));
          incidenciasPendientes.clear();
        }
        entradaPendiente = reg;
      } else if (reg.tipo == 'Salida') {
        if (entradaPendiente != null) {
          sesiones.add(SesionTrabajo(
            entrada: entradaPendiente,
            salida: reg,
            incidencias: List.of(incidenciasPendientes),
          ));
          entradaPendiente = null;
          incidenciasPendientes.clear();
        } else {
          sesiones.add(SesionTrabajo(
            entrada: null,
            salida: reg,
            incidencias: [],
          ));
        }
      } else if (reg.tipo != null && reg.tipo!.toLowerCase().startsWith('incidencia')) {
        String contexto = 'Sin entrada/salida';
        if (reg.tipo!.toLowerCase() == 'incidenciaentrada') {
          contexto = 'Salida'; // Invertido según requerimiento
        } else if (reg.tipo!.toLowerCase() == 'incidenciasalida') {
          contexto = 'Entrada'; // Invertido según requerimiento
        }

        if (entradaPendiente == null && contexto == 'Sin entrada/salida') {
          sesiones.add(SesionTrabajo(
            entrada: null,
            salida: null,
            incidencias: [IncidenciaEnSesion(reg, contexto)],
          ));
        } else {
          incidenciasPendientes.add(IncidenciaEnSesion(reg, contexto));
        }
      }
    }

    if (entradaPendiente != null) {
      sesiones.add(SesionTrabajo(
        entrada: entradaPendiente,
        salida: null,
        incidencias: List.of(incidenciasPendientes),
      ));
      incidenciasPendientes.clear();
    }

    // Añadimos incidencias sin sesión que hayan quedado pendientes
    if (incidenciasPendientes.isNotEmpty) {
      final sinContexto = incidenciasPendientes.where((inc) => inc.contexto == 'Sin entrada/salida').toList();
      for (var inc in sinContexto) {
        sesiones.add(SesionTrabajo(
          entrada: null,
          salida: null,
          incidencias: [inc],
        ));
      }
    }

    return sesiones.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final sesiones = _agruparSesiones(registros);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi histórico", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.blue),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtros de año y mes
            Row(
              children: [
                const Text("Año:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedYear,
                  items: _buildYears(),
                  onChanged: (v) => setState(() {
                    _selectedYear = v!;
                    _cargarRegistros();
                  }),
                ),
                const SizedBox(width: 16),
                const Text("Mes:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: _buildMonths(),
                  onChanged: (v) => setState(() {
                    _selectedMonth = v!;
                    _cargarRegistros();
                  }),
                ),
              ],
            ),
            const Divider(),
            if (cargando)
              const Center(child: CircularProgressIndicator()),
            if (!cargando && errorMsg != null)
              Text(errorMsg!, style: const TextStyle(color: Colors.red)),
            if (!cargando && errorMsg == null)
              Expanded(
                child: sesiones.isEmpty
                    ? const Center(child: Text('No hay fichajes para este mes.'))
                    : ListView.separated(
                        itemCount: sesiones.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          final s = sesiones[i];

                          if (s.entrada == null && s.salida == null && s.incidencias.isNotEmpty) {
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: s.incidencias.map((inc) => Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Incidencia: ${inc.incidencia.incidenciaCodigo ?? '-'}'
                                          '${inc.incidencia.observaciones != null ? ' (${inc.incidencia.observaciones})' : ''}',
                                          style: const TextStyle(color: Colors.orange),
                                        ),
                                      ),
                                    ],
                                  )).toList(),
                                ),
                              ),
                            );
                          }

                          final entrada = s.entrada?.fechaEntrada ?? '--';
                          final salida = s.salida?.fechaSalida ?? '--';

                          String tiempo = '';
                          if (s.entrada != null && s.salida != null) {
                            final dtIn = DateTime.tryParse(s.entrada!.fechaEntrada);
                            final dtOut = DateTime.tryParse(s.salida!.fechaSalida ?? '');
                            if (dtIn != null && dtOut != null && dtOut.isAfter(dtIn)) {
                              final d = dtOut.difference(dtIn);
                              tiempo = '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')} h';
                            }
                          }

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.login, size: 18, color: Colors.green),
                                          const SizedBox(width: 5),
                                          Expanded(child: Text('Entrada: $entrada', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.logout, size: 18, color: Colors.red),
                                          const SizedBox(width: 5),
                                          Expanded(child: Text('Salida:  $salida', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (tiempo.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text('Tiempo trabajado: $tiempo', style: TextStyle(color: Colors.blue)),
                                    ),
                                  if (s.incidencias.isNotEmpty)
                                    ...s.incidencias.map((inc) => Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Incidencia: ${inc.incidencia.incidenciaCodigo ?? '-'}'
                                            '${inc.incidencia.observaciones != null ? ' (${inc.incidencia.observaciones})' : ''}'
                                            ' — ${inc.contexto}',
                                            style: const TextStyle(color: Colors.orange),
                                          ),
                                        ),
                                      ],
                                    )),
                                ],
                              ),
                            ),
                          );
                        }),
              ),
          ],
        ),
      ),
    );
  }
}
