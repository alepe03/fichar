import 'package:flutter/material.dart';
import '../models/historico.dart';
import '../services/historico_service.dart';

// Pantalla para mostrar el histórico de fichajes de un usuario concreto
class HistoricoScreen extends StatefulWidget {
  final String usuario;      // Usuario del que se muestran los fichajes
  final String cifEmpresa;   // CIF de la empresa

  const HistoricoScreen({Key? key, required this.usuario, required this.cifEmpresa}) : super(key: key);

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Historico> registros = []; // Lista de fichajes filtrados
  bool cargando = true;           // Estado de carga
  String? errorMsg;               // Mensaje de error si ocurre

  int _selectedYear = DateTime.now().year;   // Año seleccionado para filtrar
  int _selectedMonth = DateTime.now().month; // Mes seleccionado para filtrar

  @override
  void initState() {
    super.initState();
    _cargarRegistros(); // Carga los registros al iniciar la pantalla
  }

  // Carga los fichajes del usuario y los filtra por año y mes seleccionados
  Future<void> _cargarRegistros() async {
    setState(() {
      cargando = true;
      errorMsg = null;
    });
    try {
      final all = await HistoricoService.obtenerFichajesUsuario(widget.usuario, widget.cifEmpresa);
      registros = all.where((h) {
        String? fecha;
        if (h.tipo == 'Salida') {
          fecha = h.fechaSalida;
        } else {
          fecha = h.fechaEntrada;
        }
        if (fecha == null || fecha.isEmpty) return false;
        final dt = DateTime.tryParse(fecha);
        return dt != null && dt.year == _selectedYear && dt.month == _selectedMonth;
      }).toList();

      // Ordena los registros por fecha relevante descendente (más reciente primero)
      registros.sort((a, b) {
        final fechaA = (a.tipo == 'Salida' ? a.fechaSalida : a.fechaEntrada) ?? '';
        final fechaB = (b.tipo == 'Salida' ? b.fechaSalida : b.fechaEntrada) ?? '';
        final dtA = DateTime.tryParse(fechaA) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse(fechaB) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });
    } catch (e) {
      errorMsg = 'Error cargando registros: $e';
    }
    setState(() {
      cargando = false;
    });
  }

  // Construye la lista de años para el filtro
  List<DropdownMenuItem<int>> _buildYears() {
    final now = DateTime.now();
    final years = List.generate(6, (i) => now.year - i);
    return years
        .map((y) => DropdownMenuItem<int>(
              value: y,
              child: Text('$y'),
            ))
        .toList();
  }

  // Construye la lista de meses para el filtro
  List<DropdownMenuItem<int>> _buildMonths() {
    return List.generate(12, (i) => i + 1)
        .map((m) => DropdownMenuItem<int>(
              value: m,
              child: Text('${m.toString().padLeft(2, '0')}'),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
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
            // Muestra el estado de carga, error o la lista de fichajes
            if (cargando)
              const Center(child: CircularProgressIndicator()),
            if (!cargando && errorMsg != null)
              Text(errorMsg!, style: const TextStyle(color: Colors.red)),
            if (!cargando && errorMsg == null)
              Expanded(
                child: registros.isEmpty
                    ? const Center(child: Text('No hay fichajes para este mes.'))
                    : ListView.separated(
                        itemCount: registros.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          final h = registros[i];
                          // Cada ficha muestra el tipo, fecha y detalles de la incidencia/observaciones si existen
                          return ListTile(
                            leading: Icon(
                              h.tipo == 'Entrada'
                                  ? Icons.login
                                  : h.tipo == 'Salida'
                                      ? Icons.logout
                                      : Icons.warning_amber_rounded,
                              color: h.tipo == 'Entrada'
                                  ? Colors.green
                                  : h.tipo == 'Salida'
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                            title: Text('${h.tipo}  -  ${(h.tipo == 'Salida' ? h.fechaSalida : h.fechaEntrada) ?? ''}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (h.incidenciaCodigo != null && h.incidenciaCodigo!.isNotEmpty)
                                  Text('Incidencia: ${h.incidenciaCodigo}'),
                                if (h.observaciones != null && h.observaciones!.isNotEmpty)
                                  Text('Obs: ${h.observaciones}'),
                              ],
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
