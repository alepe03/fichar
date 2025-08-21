import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' as html;
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../models/empleado.dart';
import '../models/horario_empleado.dart';
import '../services/historico_service.dart';
import '../services/incidencia_service.dart';

const Color kPrimaryBlue = Color.fromARGB(255, 33, 150, 243);

// ====== Modelos auxiliares ======
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
  String contexto; // "Entrada", "Salida", o "Sin entrada/salida"
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
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  
  List<Historico> registros = [];
  List<Incidencia> incidencias = [];
  List<Empleado> empleados = [];
  List<HorarioEmpleado> horarios = [];
  bool cargando = true;
  String? errorMsg;



  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  // ------------------ UI helpers ------------------
  List<DropdownMenuItem<int>> _buildYears() {
    // Años fijos desde 2024 hasta 2028
    final years = [2024, 2025, 2026, 2027, 2028];
    return years.map((y) => DropdownMenuItem<int>(value: y, child: Text('$y'))).toList();
  }

  List<DropdownMenuItem<int>> _buildMonths() {
    return List.generate(12, (i) => i + 1)
        .map((m) => DropdownMenuItem<int>(value: m, child: Text(m.toString().padLeft(2, '0'))))
        .toList();
  }

  // ------------------ Datos / filtros ------------------
  List<Historico> _filtrarRegistros(List<Historico> registros) {
    return registros.where((reg) {
      // Solo mostrar registros del empleado específico
      if (reg.usuario != widget.usuario) return false;
      
      final fechaStr =
          (reg.tipo?.toLowerCase() == 'salida') ? reg.fechaSalida : reg.fechaEntrada;
      if (fechaStr == null || fechaStr.isEmpty) return false;
      final dt = DateTime.tryParse(fechaStr);
      if (dt == null) return false;
      return dt.year == _selectedYear && dt.month == _selectedMonth;
    }).toList();
  }

  List<SesionTrabajo> _agruparSesionesPorUsuario(List<Historico> registros) {
    // Agrupa por usuario y ordena cronológicamente
    final Map<String, List<Historico>> porUsuario = {};
    for (final reg in registros) {
      final u = reg.usuario;
      if (u == null) continue;
      porUsuario.putIfAbsent(u, () => []).add(reg);
    }

    final List<SesionTrabajo> sesiones = [];
    porUsuario.forEach((usuario, regsUsuario) {
      regsUsuario.sort((a, b) {
        final fa = (a.tipo?.toLowerCase() == 'salida'
                ? a.fechaSalida
                : a.fechaEntrada) ??
            '';
        final fb = (b.tipo?.toLowerCase() == 'salida'
                ? b.fechaSalida
                : b.fechaEntrada) ??
            '';
        return fa.compareTo(fb);
      });

      Historico? entradaPendiente;
      final List<IncidenciaEnSesion> incidenciasPendientes = [];

      for (final reg in regsUsuario) {
        final t = reg.tipo?.toLowerCase();
        if (t == 'entrada') {
          if (entradaPendiente != null) {
            sesiones.add(SesionTrabajo(
              entrada: entradaPendiente,
              salida: null,
              incidencias: List.of(incidenciasPendientes),
            ));
            incidenciasPendientes.clear();
          }
          entradaPendiente = reg;
        } else if (t == 'salida') {
          if (entradaPendiente != null) {
            sesiones.add(SesionTrabajo(
              entrada: entradaPendiente,
              salida: reg,
              incidencias: List.of(incidenciasPendientes),
            ));
            entradaPendiente = null;
            incidenciasPendientes.clear();
          } else {
            // Salida sin entrada
            sesiones.add(
                SesionTrabajo(entrada: null, salida: reg, incidencias: const []));
          }
        } else if (t != null &&
            (t.startsWith('incidencia') || t.startsWith('Incidencia'))) {
          String contexto = 'Sin entrada/salida';
          if (t.toLowerCase() == 'incidenciaentrada') contexto = 'Salida';
          if (t.toLowerCase() == 'incidenciasalida') contexto = 'Entrada';

          if (entradaPendiente == null && contexto == 'Sin entrada/salida') {
            sesiones.add(SesionTrabajo(
                entrada: null, salida: null, incidencias: [IncidenciaEnSesion(reg, contexto)]));
          } else {
            incidenciasPendientes.add(IncidenciaEnSesion(reg, contexto));
          }
        }
      }

      // Cierra entrada huérfana
      if (entradaPendiente != null) {
        sesiones.add(SesionTrabajo(
          entrada: entradaPendiente,
          salida: null,
          incidencias: List.of(incidenciasPendientes),
        ));
        incidenciasPendientes.clear();
      }

      // Incidencias sueltas residual
      if (incidenciasPendientes.isNotEmpty) {
        for (var inc in incidenciasPendientes
            .where((x) => x.contexto == 'Sin entrada/salida')) {
          sesiones.add(
              SesionTrabajo(entrada: null, salida: null, incidencias: [inc]));
        }
      }
    });

    // Orden descendente por fecha
    sesiones.sort((a, b) {
      final fa = a.entrada?.fechaEntrada ?? a.salida?.fechaSalida ?? '';
      final fb = b.entrada?.fechaEntrada ?? b.salida?.fechaSalida ?? '';
      return fb.compareTo(fa);
    });
    return sesiones;
  }

  // ------------------ Helpers de fechas/tiempo ------------------
  final DateFormat _fmt = DateFormat('dd/MM/yyyy HH:mm');

  String _formatFecha(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '-';
    final dt = DateTime.tryParse(fechaStr);
    if (dt == null) return '-';
    return _fmt.format(dt);
  }

  int _diffMinutos(DateTime inicio, DateTime fin) {
    return fin.isAfter(inicio) ? fin.difference(inicio).inMinutes : 0;
  }

  String _formatMinutos(int minutos) {
    final h = (minutos ~/ 60).toString().padLeft(2, '0');
    final m = (minutos % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }



  DateTime? _parse(String? s) =>
      (s == null || s.isEmpty) ? null : DateTime.tryParse(s);



  Future<void> _cargarRegistros() async {
    setState(() {
      cargando = true;
      errorMsg = null;
    });
    
    try {
      final all = await HistoricoService.obtenerFichajesUsuario(widget.usuario, widget.cifEmpresa);
      registros = all;

      // Cargar datos adicionales para el PDF
      try {
        incidencias = await IncidenciaService.cargarIncidenciasLocal(widget.cifEmpresa);
        // Por ahora no cargamos empleados y horarios, los manejaremos de otra forma
      } catch (e) {
        // Silenciar error de datos adicionales
      }
    } catch (e) {
      errorMsg = 'Error cargando registros: $e';
    }
    
    setState(() {
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrosFiltrados = _filtrarRegistros(registros);
    final sesiones = _agruparSesionesPorUsuario(registrosFiltrados);

    final Map<String, Empleado> mapaEmpleados = {
      for (var e in empleados) e.usuario: e
    };
    final Map<String, Incidencia> mapaIncidencias = {
      for (var i in incidencias) i.codigo: i
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mi histórico", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        errorMsg!,
                        style: const TextStyle(fontSize: 18, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: DropdownButton<int>(
                                  value: _selectedYear,
                                  items: _buildYears(),
                                  onChanged: (v) => setState(() => _selectedYear = v!),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: DropdownButton<int>(
                                  value: _selectedMonth,
                                  items: _buildMonths(),
                                  onChanged: (v) =>
                                      setState(() => _selectedMonth = v!),
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Exportar PDF'),
                                onPressed: () => _exportarPdfDescargar(
                                    sesiones, mapaEmpleados, mapaIncidencias),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de fichajes
                    Expanded(
                      child: sesiones.isEmpty
                          ? const Center(
                              child: Text(
                                  'No hay fichajes para el filtro seleccionado.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: sesiones.length,
                              itemBuilder: (context, index) {
                                final s = sesiones[index];

                                final usuario = s.entrada?.usuario ??
                                    s.salida?.usuario ??
                                    (s.incidencias.isNotEmpty
                                        ? s.incidencias.first.incidencia.usuario
                                        : null);
                                final emp =
                                    (usuario != null) ? mapaEmpleados[usuario] : null;

                                final dtE = _parse(s.entrada?.fechaEntrada);
                                final dtS = _parse(s.salida?.fechaSalida);
                                final entradaStr =
                                    _formatFecha(s.entrada?.fechaEntrada);
                                final salidaStr =
                                    _formatFecha(s.salida?.fechaSalida);

                                int minTrab = 0;
                                if (dtE != null && dtS != null) {
                                  minTrab = _diffMinutos(dtE, dtS);
                                }
                                final tiempoStr =
                                    (minTrab > 0) ? _formatMinutos(minTrab) : '-';

                                final dni =
                                    emp?.dni ?? s.entrada?.dniEmpleado ?? s.salida?.dniEmpleado ?? '-';

                                String ordStr = '-';
                                if (dni != '-' && dtE != null) {
                                  // Por ahora no calculamos horas ordinarias
                                  ordStr = '-';
                                }

                                final incidenciasText = s.incidencias.isNotEmpty
                                    ? s.incidencias.map((inc) {
                                        final codigo =
                                            inc.incidencia.incidenciaCodigo;
                                        if (codigo == null || codigo.isEmpty) {
                                          return 'Sin código';
                                        }
                                        final incDef = mapaIncidencias[codigo];
                                        final descripcion =
                                            incDef?.descripcion ?? codigo;
                                        return '$codigo - $descripcion';
                                      }).join(', ')
                                    : '-';

                                return _SessionCompactCard(
                                  empleado: emp?.nombre ?? usuario ?? 'Desconocido',
                                  dni: dni,
                                  entrada: entradaStr,
                                  salida: salidaStr,
                                  tiempo: tiempoStr,
                                  ordinarias: ordStr,
                                  incidencias: incidenciasText,
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  // ------------------ PDF ------------------
  Future<pw.Document> _crearPdf({
    required List<SesionTrabajo> sesiones,
    required Map<String, Empleado> mapaEmpleados,
    required Map<String, Incidencia> mapaIncidencias,
  }) async {
    final pdf = pw.Document();

    // Paleta azul/blanco
    const PdfColor azul = PdfColor.fromInt(0xFF2196F3);
    const PdfColor azulClaro = PdfColor.fromInt(0xFFE3F2FD);
    const PdfColor blanco = PdfColor.fromInt(0xFFFFFFFF);
    const PdfColor grisTexto = PdfColor.fromInt(0xFF444444);

    // Theme más compacto
    final theme = pw.ThemeData(
      defaultTextStyle: const pw.TextStyle(color: grisTexto, fontSize: 9),
    );

    // Cabecera de documento
    final titulo = 'Fichajes ${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')} · ${widget.usuario}';

    // Cabeceras tabla principal
    final headers = [
      'Empleado',
      'DNI',
      'Entrada',
      'Salida',
      'Tiempo',
      'Incidencias',
    ];

    List<pw.TableRow> buildMainTableRows() {
      final rows = <pw.TableRow>[];

      // Header
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: azul),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                          color: blanco,
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ))
              .toList(),
        ),
      );

      // Body
      for (int i = 0; i < sesiones.length; i++) {
        final sesion = sesiones[i];

        final usuario = sesion.entrada?.usuario ??
            sesion.salida?.usuario ??
            (sesion.incidencias.isNotEmpty
                ? sesion.incidencias.first.incidencia.usuario
                : null);

        final empleado = (usuario != null) ? mapaEmpleados[usuario] : null;

        final entradaStr = _formatFecha(sesion.entrada?.fechaEntrada);
        final salidaStr = _formatFecha(sesion.salida?.fechaSalida);

        // Tiempo trabajado (min)
        int minutosTrabajados = 0;
        final dtE = _parse(sesion.entrada?.fechaEntrada);
        final dtS = _parse(sesion.salida?.fechaSalida);
        if (dtE != null && dtS != null) {
          minutosTrabajados = _diffMinutos(dtE, dtS);
        }
        final tiempoTrabajadoStr =
            minutosTrabajados > 0 ? '${_formatMinutos(minutosTrabajados)} h' : '-';

        // Incidencias -> CÓDIGO + DESCRIPCIÓN
        final incidenciasText = sesion.incidencias.isNotEmpty
            ? sesion.incidencias.map((inc) {
                final codigo = inc.incidencia.incidenciaCodigo;
                if (codigo == null || codigo.isEmpty) return 'Sin código';
                final incidencia = mapaIncidencias[codigo];
                final descripcion = incidencia?.descripcion ?? codigo;
                return '$codigo - $descripcion';
              }).join(', ')
            : '-';

        final rowColor =
            (i % 2 == 0) ? null : const pw.BoxDecoration(color: azulClaro);

        rows.add(
          pw.TableRow(
            decoration: rowColor,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(empleado?.nombre ?? usuario ?? 'Desconocido'),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(empleado?.dni ??
                      sesion.entrada?.dniEmpleado ??
                      sesion.salida?.dniEmpleado ??
                      '-'),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                    alignment: pw.Alignment.center, child: pw.Text(entradaStr)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                    alignment: pw.Alignment.center, child: pw.Text(salidaStr)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(tiempoTrabajadoStr)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(incidenciasText, maxLines: 3, softWrap: true),
              ),
            ],
          ),
        );
      }
      return rows;
    }

    // --------- Render PDF ---------
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(20, 22, 20, 22),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Container(
            decoration: const pw.BoxDecoration(
              color: azul,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Mi histórico de fichajes',
                  style: pw.TextStyle(
                      color: blanco,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(titulo,
                    style:
                        const pw.TextStyle(color: blanco, fontSize: 9)),
              ],
            ),
          ),
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3), // Empleado
              1: pw.FlexColumnWidth(0.9), // DNI
              2: pw.FlexColumnWidth(1.0), // Entrada
              3: pw.FlexColumnWidth(1.0), // Salida
              4: pw.FlexColumnWidth(0.8), // Tiempo
              5: pw.FlexColumnWidth(1.4), // Incidencias
            },
            children: buildMainTableRows(),
          ),
        ],
      ),
    );

    return pdf;
  }

  // ------------------ Guardado ------------------
  Future<dynamic> _guardarPdfEnDispositivo(Uint8List pdfBytes) async {
    if (kIsWeb) {
      // En web, retornar los bytes para descarga
      return pdfBytes;
    } else {
      // En móvil/desktop, usar path_provider como antes
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'fichajes_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${widget.usuario}.pdf';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      return filePath;
    }
  }

  Future<void> _exportarPdfDescargar(
    List<SesionTrabajo> sesiones,
    Map<String, Empleado> mapaEmpleados,
    Map<String, Incidencia> mapaIncidencias,
  ) async {
    try {
      final pdf = await _crearPdf(
        sesiones: sesiones,
        mapaEmpleados: mapaEmpleados,
        mapaIncidencias: mapaIncidencias,
      );
      final pdfBytes = await pdf.save();
      final resultado = await _guardarPdfEnDispositivo(pdfBytes);

      if (kIsWeb) {
        // En web, descargar automáticamente
        if (resultado is Uint8List) {
          _downloadPdfWeb(resultado, 'fichajes_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${widget.usuario}.pdf');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF exportado y descargado correctamente')),
            );
          }
        }
      } else {
        // En móvil/desktop, guardar y abrir
        if (resultado is String) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('PDF guardado en: $resultado')));
          }

          final openResult = await OpenFile.open(resultado);
          if (openResult.type != ResultType.done && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No se pudo abrir el PDF automáticamente.')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar PDF: $e')),
        );
      }
    }
  }

  // Función para descargar PDF en web
  void _downloadPdfWeb(List<int> bytes, String filename) {
    if (kIsWeb) {
      // Crear un blob y descargarlo usando universal_html
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    }
  }
}

// ====== UI: Tarjeta compacta y moderna por sesión (SOLO FICHAJES) ======
class _SessionCompactCard extends StatelessWidget {
  final String empleado;
  final String dni;
  final String entrada;
  final String salida;
  final String tiempo;
  final String ordinarias;
  final String incidencias;

  const _SessionCompactCard({
    Key? key,
    required this.empleado,
    required this.dni,
    required this.entrada,
    required this.salida,
    required this.tiempo,
    required this.ordinarias,
    required this.incidencias,
  }) : super(key: key);

  // Pill genérica con soporte de colores personalizados (bg/fg)
  Widget _pill(
    BuildContext context,
    String text, {
    IconData? icon,
    Color? bg,
    Color? fg,
  }) {
    final themePrimary = Theme.of(context).colorScheme.primary;
    final background = bg ?? themePrimary.withValues(alpha: 0.08);
    final foreground = fg ?? themePrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg ?? foreground),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg ?? foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon ?? Icons.info_outline, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              )),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divider =
        VerticalDivider(color: Colors.grey.shade300, thickness: 1, width: 16);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: Empleado + DNI badge (azul sólido)
            Row(
              children: [
                Expanded(
                  child: Text(
                    empleado,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _pill(
                  context,
                  dni,
                  icon: Icons.badge_outlined,
                  bg: Colors.blue,
                  fg: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dos columnas: Entrada | Salida (responsivo)
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth > 560;
                final entradaSection = _section('Entrada', [
                  _kv('Fecha y hora', entrada, icon: Icons.login),
                ]);
                final salidaSection = _section('Salida', [
                  _kv('Fecha y hora', salida, icon: Icons.logout),
                ]);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: entradaSection),
                      divider,
                      Expanded(child: salidaSection),
                    ],
                  );
                }
                return Column(
                  children: [
                    entradaSection,
                    const SizedBox(height: 10),
                    salidaSection,
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Pills: Tiempo + Ordinarias (azul sólido)
            Row(
              children: [
                _pill(
                  context,
                  'Tiempo: $tiempo',
                  icon: Icons.timer_outlined,
                  bg: Colors.blue,
                  fg: Colors.white,
                ),
                const SizedBox(width: 8),
                _pill(
                  context,
                  'Ordinarias: $ordinarias',
                  icon: Icons.schedule_outlined,
                  bg: Colors.blue,
                  fg: Colors.white,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Incidencias
            if (incidencias != '-' && incidencias.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        incidencias,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
