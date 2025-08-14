import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../models/historico.dart';
import '../models/incidencia.dart';
import '../services/historico_service.dart';
import '../services/incidencia_service.dart';

const Color kPrimaryBlue = Color.fromARGB(255, 33, 150, 243);

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
  String contexto;
  IncidenciaEnSesion(this.incidencia, this.contexto);
}

class HistoricoScreen extends StatefulWidget {
  final String usuario;
  final String cifEmpresa;

  const HistoricoScreen({Key? key, required this.usuario, required this.cifEmpresa}) : super(key: key);

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Historico> registros = [];
  List<Incidencia> incidencias = [];
  bool cargando = true;
  String? errorMsg;
  String? _dniUsuario;

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

      if (registros.isNotEmpty) {
        _dniUsuario = registros.firstWhere(
          (h) => h.dniEmpleado != null && h.dniEmpleado!.isNotEmpty,
          orElse: () => registros.first,
        ).dniEmpleado;
      }

      registros.sort((a, b) {
        final fechaA = (a.tipo == 'Salida' ? a.fechaSalida : a.fechaEntrada) ?? '';
        final fechaB = (b.tipo == 'Salida' ? b.fechaSalida : b.fechaEntrada) ?? '';
        final dtA = DateTime.tryParse(fechaA) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse(fechaB) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtA.compareTo(dtB);
      });

      // Cargar incidencias para mostrar descripciones en el PDF
      try {
        incidencias = await IncidenciaService.cargarIncidenciasLocal(widget.cifEmpresa);
      } catch (e) {
        // Si no se pueden cargar las incidencias, continuamos sin ellas
        print('No se pudieron cargar las incidencias: $e');
      }
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
          contexto = 'Salida';
        } else if (reg.tipo!.toLowerCase() == 'incidenciasalida') {
          contexto = 'Entrada';
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

  String formatFecha(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '-';
    final dt = DateTime.tryParse(fechaStr);
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<pw.Document> _crearPdf(List<SesionTrabajo> sesiones) async {
    final pdf = pw.Document();
    final usuario = widget.usuario;
    final dni = _dniUsuario ?? '-';

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('Mi histórico de fichajes', style: pw.TextStyle(fontSize: 24))),
            pw.Table.fromTextArray(
              headers: ['Usuario', 'DNI', 'Entrada', 'Salida', 'Tiempo trabajado', 'Incidencias'],
              data: sesiones.map((sesion) {
                final entradaStr = formatFecha(sesion.entrada?.fechaEntrada);
                final salidaStr = formatFecha(sesion.salida?.fechaSalida);

                String tiempoTrabajado = '';
                if (sesion.entrada != null && sesion.salida != null) {
                  final dtEntrada = DateTime.tryParse(sesion.entrada!.fechaEntrada);
                  final dtSalida = DateTime.tryParse(sesion.salida!.fechaSalida ?? '');
                  if (dtEntrada != null && dtSalida != null && dtSalida.isAfter(dtEntrada)) {
                    final duracion = dtSalida.difference(dtEntrada);
                    final horas = duracion.inHours.toString().padLeft(2, '0');
                    final minutos = (duracion.inMinutes % 60).toString().padLeft(2, '0');
                    tiempoTrabajado = '$horas:$minutos h';
                  }
                }

                final incidenciasText = sesion.incidencias.isNotEmpty
                    ? sesion.incidencias.map((inc) {
                        final codigo = inc.incidencia.incidenciaCodigo;
                        
                        // Si no hay código de incidencia, mostrar "Sin código"
                        if (codigo == null || codigo.isEmpty) {
                          return 'Sin código';
                        }
                        
                        // Buscar la incidencia en la lista para obtener la descripción
                        final incidencia = incidencias.firstWhere(
                          (i) => i.codigo == codigo,
                          orElse: () => Incidencia(codigo: codigo),
                        );
                        final descripcion = incidencia.descripcion ?? codigo;
                        
                        // Solo mostrar código y descripción
                        return '$codigo - $descripcion';
                      }).join(', ')
                    : '-';

                return [usuario, dni, entradaStr, salidaStr, tiempoTrabajado.isNotEmpty ? tiempoTrabajado : '-', incidenciasText];
              }).toList(),
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  Future<String> _guardarPdfEnDispositivo(Uint8List pdfBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'fichajes_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${widget.usuario}.pdf';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }

  Future<void> _exportarPdfDescargar(List<SesionTrabajo> sesiones) async {
    try {
      // Usar datos locales para asegurar que las incidencias tengan toda la información
      final fichajesLocales = await HistoricoService.obtenerFichajesUsuario(widget.usuario, widget.cifEmpresa);
      final registrosFiltrados = fichajesLocales.where((h) {
        String? fecha = (h.tipo == 'Salida') ? h.fechaSalida : h.fechaEntrada;
        if (fecha == null || fecha.isEmpty) return false;
        final dt = DateTime.tryParse(fecha);
        return dt != null && dt.year == _selectedYear && dt.month == _selectedMonth;
      }).toList();
      final sesionesLocales = _agruparSesiones(registrosFiltrados);
      
      final pdf = await _crearPdf(sesionesLocales);
      final pdfBytes = await pdf.save();
      final rutaGuardado = await _guardarPdfEnDispositivo(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF guardado en: $rutaGuardado')));
      }

      final resultado = await OpenFile.open(rutaGuardado);
      if (resultado.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el PDF automáticamente.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesiones = _agruparSesiones(registros);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mi histórico", style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryBlue),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Filtros + botón adaptables con Wrap
            Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                  label: const Text('Exportar', style: TextStyle(color: Colors.white, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: cargando || sesiones.isEmpty ? null : () => _exportarPdfDescargar(sesiones),
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

                          final entrada = formatFecha(s.entrada?.fechaEntrada);
                          final salida = formatFecha(s.salida?.fechaSalida);

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
                                      child: Text('Tiempo trabajado: $tiempo', style: TextStyle(color: kPrimaryBlue)),
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
