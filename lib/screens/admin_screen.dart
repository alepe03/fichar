import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

import '../models/empleado.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../providers/admin_provider.dart';
import '../models/horario_empleado.dart';

const Color kPrimaryBlue = Color.fromARGB(255, 33, 150, 243);

class AdminScreen extends StatefulWidget {
  final String cifEmpresa;
  const AdminScreen({Key? key, required this.cifEmpresa}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 tabs ahora
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _isLoading = true);
      final provider = Provider.of<AdminProvider>(context, listen: false);
      await provider.cargarDatosIniciales(); // carga empleados, historicos, incidencias
      // Si quieres cargar horarios globales o por empleado, lo haces aquí también o en el tab
      setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Panel de Administración', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 3,
        backgroundColor: kPrimaryBlue,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Usuarios'),
            Tab(text: 'Fichajes'),
            Tab(text: 'Incidencias'),
            Tab(text: 'Horarios'), // nuevo tab
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: const [
                UsuariosTab(),
                FichajesTab(),
                IncidenciasTab(),
                HorariosTab(), // nuevo tab view
              ],
            ),
    );
  }
}

// ===== Usuarios Tab =====
enum FiltroEstado { todos, activos, inactivos }

class UsuariosTab extends StatefulWidget {
  const UsuariosTab({Key? key}) : super(key: key);

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  FiltroEstado filtro = FiltroEstado.activos;

  void _abrirDialogo(BuildContext context, AdminProvider provider, {Empleado? empleado}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _FormularioEmpleado(
            cifEmpresa: provider.cifEmpresa,
            empleadoExistente: empleado,
            onSubmit: (nuevo, usuarioOriginal) async {
              String? error;
              if (empleado == null) {
                error = await provider.addEmpleado(nuevo);
              } else {
                error = await provider.updateEmpleado(nuevo, usuarioOriginal);
              }
              if (context.mounted) Navigator.pop(context);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        List<Empleado> empleadosFiltrados;
        switch (filtro) {
          case FiltroEstado.todos:
            empleadosFiltrados = provider.empleados;
            break;
          case FiltroEstado.activos:
            empleadosFiltrados = provider.empleados.where((e) => e.activo == 1).toList();
            break;
          case FiltroEstado.inactivos:
            empleadosFiltrados = provider.empleados.where((e) => e.activo == 0).toList();
            break;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: filtro == FiltroEstado.todos,
                    onSelected: (_) => setState(() => filtro = FiltroEstado.todos),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Activos'),
                    selected: filtro == FiltroEstado.activos,
                    onSelected: (_) => setState(() => filtro = FiltroEstado.activos),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Inactivos'),
                    selected: filtro == FiltroEstado.inactivos,
                    onSelected: (_) => setState(() => filtro = FiltroEstado.inactivos),
                  ),
                ],
              ),
            ),

            Expanded(
              child: empleadosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay usuarios para el filtro seleccionado.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const Divider(height: 16, thickness: 1),
                      itemCount: empleadosFiltrados.length,
                      itemBuilder: (context, index) {
                        final emp = empleadosFiltrados[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(emp.nombre ?? emp.usuario,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                            subtitle: Text(
                                '${emp.email ?? 'Sin email'} · Rol: ${emp.rol ?? 'N/D'} · Estado: ${emp.activo == 1 ? 'Activo' : 'Inactivo'}',
                                style: const TextStyle(fontSize: 14)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    emp.activo == 1 ? Icons.block : Icons.check_circle,
                                    color: emp.activo == 1 ? Colors.orange : Colors.green,
                                  ),
                                  tooltip: emp.activo == 1 ? 'Dar de baja' : 'Reactivar usuario',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(emp.activo == 1 ? 'Confirmar baja' : 'Confirmar reactivación'),
                                        content: Text(emp.activo == 1
                                            ? '¿Quieres dar de baja al usuario "${emp.usuario}"?'
                                            : '¿Quieres reactivar al usuario "${emp.usuario}"?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final nuevoEstado = emp.activo == 1 ? 0 : 1;
                                      final error = await provider.updateEmpleado(
                                        emp.copyWith(activo: nuevoEstado),
                                        emp.usuario,
                                      );
                                      if (error != null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () => _abrirDialogo(context, provider, empleado: emp),
                          ),
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16, right: 16),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton.extended(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text(
                    'Añadir usuario',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => _abrirDialogo(context, provider),
                  backgroundColor: Colors.blue,
                  elevation: 6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


class _FormularioEmpleado extends StatefulWidget {
  final String cifEmpresa;
  final Empleado? empleadoExistente;
  final void Function(Empleado empleado, String usuarioOriginal) onSubmit;

  const _FormularioEmpleado({
    required this.cifEmpresa,
    this.empleadoExistente,
    required this.onSubmit,
  });

  @override
  State<_FormularioEmpleado> createState() => _FormularioEmpleadoState();
}

class _FormularioEmpleadoState extends State<_FormularioEmpleado> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usuarioCtrl;
  late TextEditingController _nombreCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _poblacionCtrl;
  late TextEditingController _codigoPostalCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _passwordCtrl;

  final _roles = ['admin', 'supervisor', 'empleado'];
  String? _rolSeleccionado;
  bool _puedeLocalizar = false;
  bool _activo = true;

  late String _usuarioOriginal;

  @override
  void initState() {
    super.initState();
    final emp = widget.empleadoExistente;
    _usuarioCtrl = TextEditingController(text: emp?.usuario ?? '');
    _nombreCtrl = TextEditingController(text: emp?.nombre ?? '');
    _emailCtrl = TextEditingController(text: emp?.email ?? '');
    _direccionCtrl = TextEditingController(text: emp?.direccion ?? '');
    _poblacionCtrl = TextEditingController(text: emp?.poblacion ?? '');
    _codigoPostalCtrl = TextEditingController(text: emp?.codigoPostal ?? '');
    _telefonoCtrl = TextEditingController(text: emp?.telefono ?? '');
    _dniCtrl = TextEditingController(text: emp?.dni ?? '');
    _passwordCtrl = TextEditingController(text: emp != null ? '******' : '');
    _rolSeleccionado = emp?.rol;
    _puedeLocalizar = (emp?.puedeLocalizar ?? 0) == 1;
    _activo = (emp?.activo ?? 1) == 1;

    _usuarioOriginal = emp?.usuario ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.empleadoExistente != null;
    final theme = Theme.of(context);

    final bool puedeCambiarLocalizacion = _rolSeleccionado != 'supervisor';

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Editar empleado' : 'Nuevo empleado',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Usuario
            TextFormField(
              controller: _usuarioCtrl,
              decoration: InputDecoration(
                labelText: 'Usuario',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, color: kPrimaryBlue),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Usuario obligatorio' : null,
            ),
            const SizedBox(height: 12),

            // Nombre
            TextFormField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge, color: kPrimaryBlue),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Nombre obligatorio' : null,
            ),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.email, color: kPrimaryBlue),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Dirección
            TextFormField(
              controller: _direccionCtrl,
              decoration: InputDecoration(
                labelText: 'Dirección',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.home, color: kPrimaryBlue),
              ),
            ),
            const SizedBox(height: 12),

            // Población
            TextFormField(
              controller: _poblacionCtrl,
              decoration: InputDecoration(
                labelText: 'Población',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city, color: kPrimaryBlue),
              ),
            ),
            const SizedBox(height: 12),

            // Código Postal
            TextFormField(
              controller: _codigoPostalCtrl,
              decoration: InputDecoration(
                labelText: 'Código Postal',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_post_office, color: kPrimaryBlue),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Teléfono
            TextFormField(
              controller: _telefonoCtrl,
              decoration: InputDecoration(
                labelText: 'Teléfono',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone, color: kPrimaryBlue),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // DNI
            TextFormField(
              controller: _dniCtrl,
              decoration: InputDecoration(
                labelText: 'DNI',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card, color: kPrimaryBlue),
              ),
              validator: (v) => v == null || v.isEmpty ? 'DNI obligatorio' : null,
            ),
            const SizedBox(height: 12),

            // Contraseña
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock, color: kPrimaryBlue),
              ),
              obscureText: true,
              enabled: !isEditing, // ✅ Deshabilitado si es edición
              validator: (v) {
                if (!isEditing && (v == null || v.isEmpty)) {
                  return 'Contraseña obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Rol
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Rol',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.security, color: kPrimaryBlue),
              ),
              value: _rolSeleccionado,
              items: _roles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r == 'admin'
                            ? 'Administrador'
                            : r == 'supervisor'
                                ? 'Supervisor'
                                : 'Empleado',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _rolSeleccionado = v;
                if (v == 'supervisor') {
                  _puedeLocalizar = false;
                }
              }),
              validator: (v) => v == null ? 'Selecciona un rol' : null,
            ),
            const SizedBox(height: 12),

            // Switches
            SwitchListTile(
              title: const Text('Permitir localización'),
              value: _puedeLocalizar,
              onChanged: puedeCambiarLocalizacion
                  ? (value) {
                      setState(() {
                        _puedeLocalizar = value;
                      });
                    }
                  : null,
            ),
            SwitchListTile(
              title: const Text('Empleado activo'),
              value: _activo,
              onChanged: (value) {
                setState(() {
                  _activo = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSubmit(
                      Empleado(
                        usuario: _usuarioCtrl.text.trim(),
                        cifEmpresa: widget.cifEmpresa,
                        direccion: _direccionCtrl.text.trim(),
                        poblacion: _poblacionCtrl.text.trim(),
                        codigoPostal: _codigoPostalCtrl.text.trim(),
                        telefono: _telefonoCtrl.text.trim(),
                        email: _emailCtrl.text.trim(),
                        nombre: _nombreCtrl.text.trim(),
                        dni: _dniCtrl.text.trim(),
                        rol: _rolSeleccionado,
                        passwordHash: isEditing ? '' : _passwordCtrl.text.trim(), // ✅ Solo si es nuevo
                        puedeLocalizar: _puedeLocalizar ? 1 : 0,
                        activo: _activo ? 1 : 0,
                      ),
                      _usuarioOriginal,
                    );
                  }
                },
                child: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Fichajes Tab =====

class FichajesTab extends StatefulWidget {
  const FichajesTab({Key? key}) : super(key: key);

  @override
  State<FichajesTab> createState() => _FichajesTabState();
}

class _FichajesTabState extends State<FichajesTab> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String? _selectedUsuario;

  List<DropdownMenuItem<int>> _buildYears() {
    final now = DateTime.now();
    final years = List.generate(6, (i) => now.year - i);
    return years.map((y) => DropdownMenuItem<int>(value: y, child: Text('$y'))).toList();
  }

  List<DropdownMenuItem<int>> _buildMonths() {
    return List.generate(12, (i) => i + 1)
        .map((m) => DropdownMenuItem<int>(value: m, child: Text(m.toString().padLeft(2, '0'))))
        .toList();
  }

  List<DropdownMenuItem<String?>> _buildUsuarios(List<Empleado> empleados) {
    return [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Todos los empleados'),
      ),
      ...empleados.map(
        (e) => DropdownMenuItem<String?>(
          value: e.usuario,
          child: Text(e.nombre ?? e.usuario),
        ),
      ),
    ];
  }

  List<Historico> _filtrarRegistros(List<Historico> registros) {
    return registros.where((reg) {
      if (_selectedUsuario != null && reg.usuario != _selectedUsuario) return false;
      final fechaStr = (reg.tipo?.toLowerCase() == 'salida') ? reg.fechaSalida : reg.fechaEntrada;
      if (fechaStr == null || fechaStr.isEmpty) return false;
      final dt = DateTime.tryParse(fechaStr);
      if (dt == null) return false;
      return dt.year == _selectedYear && dt.month == _selectedMonth;
    }).toList();
  }

  List<SesionTrabajo> _agruparSesionesPorUsuario(List<Historico> registros) {
    // Agrupa por usuario, no mezcla sesiones de empleados distintos
    Map<String, List<Historico>> porUsuario = {};
    for (final reg in registros) {
      if (reg.usuario == null) continue;
      porUsuario.putIfAbsent(reg.usuario!, () => []).add(reg);
    }
    List<SesionTrabajo> sesiones = [];
    porUsuario.forEach((usuario, regsUsuario) {
      // Ordenar por fecha relevante
      regsUsuario.sort((a, b) {
        final fechaA = (a.tipo?.toLowerCase() == 'salida' ? a.fechaSalida : a.fechaEntrada) ?? '';
        final fechaB = (b.tipo?.toLowerCase() == 'salida' ? b.fechaSalida : b.fechaEntrada) ?? '';
        return fechaA.compareTo(fechaB);
      });
      Historico? entradaPendiente;
      List<IncidenciaEnSesion> incidenciasPendientes = [];
      for (final reg in regsUsuario) {
        if (reg.tipo?.toLowerCase() == 'entrada') {
          if (entradaPendiente != null) {
            sesiones.add(SesionTrabajo(
              entrada: entradaPendiente,
              salida: null,
              incidencias: List.of(incidenciasPendientes),
            ));
            incidenciasPendientes.clear();
          }
          entradaPendiente = reg;
        } else if (reg.tipo?.toLowerCase() == 'salida') {
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
    });

    // Orden descendente por fecha
    sesiones.sort((a, b) {
      final fechaA = a.entrada?.fechaEntrada ?? a.salida?.fechaSalida ?? '';
      final fechaB = b.entrada?.fechaEntrada ?? b.salida?.fechaSalida ?? '';
      return fechaB.compareTo(fechaA);
    });
    return sesiones;
  }

  String formatFecha(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '-';
    final dt = DateTime.tryParse(fechaStr);
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<pw.Document> _crearPdf(List<SesionTrabajo> sesiones, Map<String, Empleado> mapaEmpleados, Map<String, Incidencia> mapaIncidencias) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('Fichajes filtrados', style: pw.TextStyle(fontSize: 24))),
            pw.Table.fromTextArray(
              headers: [
                'Empleado',
                'DNI',
                'Entrada',
                'Salida',
                'Coordenadas Entrada',
                'Coordenadas Salida',
                'Tiempo trabajado',
                'Incidencias'
              ],
              data: sesiones.map((sesion) {
                final usuario = sesion.entrada?.usuario ?? sesion.salida?.usuario ??
                    (sesion.incidencias.isNotEmpty ? sesion.incidencias.first.incidencia.usuario : null);
                final empleado = usuario != null ? mapaEmpleados[usuario] : null;

                final entradaStr = formatFecha(sesion.entrada?.fechaEntrada);
                final salidaStr = formatFecha(sesion.salida?.fechaSalida);

                final entradaCoords = (sesion.entrada?.latitud != null && sesion.entrada?.longitud != null)
                    ? '${sesion.entrada!.latitud}, ${sesion.entrada!.longitud}'
                    : '-';

                final salidaCoords = (sesion.salida?.latitud != null && sesion.salida?.longitud != null)
                    ? '${sesion.salida!.latitud}, ${sesion.salida!.longitud}'
                    : '-';

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
                        final c = inc.incidencia.incidenciaCodigo ?? '-';
                        final o = inc.incidencia.observaciones ?? '';
                        final completa = mapaIncidencias[c];
                        final computaTexto = completa != null
                            ? (completa.computa ? 'Computa' : 'No computa')
                            : '';
                        return '$c${o.isNotEmpty ? ' ($o)' : ''}${computaTexto.isNotEmpty ? ' - $computaTexto' : ''}';
                      }).join(', ')
                    : '-';

                return [
                  empleado?.nombre ?? usuario ?? 'Desconocido',
                  empleado?.dni ?? '-',
                  entradaStr,
                  salidaStr,
                  entradaCoords,
                  salidaCoords,
                  tiempoTrabajado.isNotEmpty ? tiempoTrabajado : '-',
                  incidenciasText,
                ];
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
    final fileName = 'fichajes_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${_selectedUsuario ?? 'todos'}.pdf';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }

  Future<void> _exportarPdfDescargar(List<SesionTrabajo> sesiones, Map<String, Empleado> mapaEmpleados, Map<String, Incidencia> mapaIncidencias) async {
    try {
      final pdf = await _crearPdf(sesiones, mapaEmpleados, mapaIncidencias);
      final pdfBytes = await pdf.save();
      final rutaGuardado = await _guardarPdfEnDispositivo(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF guardado en: $rutaGuardado')),
        );
      }

      final resultado = await OpenFile.open(rutaGuardado);
      if (resultado.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el PDF automáticamente.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        if (provider.historicos.isEmpty) {
          return const Center(
            child: Text('No hay fichajes.', style: TextStyle(fontSize: 18, color: Colors.grey)),
          );
        }

        final registrosFiltrados = _filtrarRegistros(provider.historicos);
        final sesiones = _agruparSesionesPorUsuario(registrosFiltrados);

        final Map<String, Empleado> mapaEmpleados = {
          for (var e in provider.empleados) e.usuario: e
        };

        final Map<String, Incidencia> mapaIncidencias = {
          for (var i in provider.incidencias) i.codigo: i
        };

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          onChanged: (v) => setState(() {
                            _selectedYear = v!;
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          items: _buildMonths(),
                          onChanged: (v) => setState(() {
                            _selectedMonth = v!;
                          }),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            underline: const SizedBox(),
                            value: _selectedUsuario,
                            items: _buildUsuarios(provider.empleados),
                            onChanged: (v) => setState(() {
                              _selectedUsuario = v;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Exportar PDF'),
                        onPressed: () => _exportarPdfDescargar(sesiones, mapaEmpleados, mapaIncidencias),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 33, 150, 243),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: sesiones.isEmpty
                  ? const Center(child: Text('No hay fichajes para el filtro seleccionado.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sesiones.length,
                      itemBuilder: (context, index) {
                        final sesion = sesiones[index];
                        final esSoloIncidencia = sesion.entrada == null && sesion.salida == null;

                        Empleado? empleado;
                        String? usuarioIncidencia;

                        if (esSoloIncidencia && sesion.incidencias.isNotEmpty) {
                          usuarioIncidencia = sesion.incidencias.first.incidencia.usuario;
                          empleado = usuarioIncidencia != null ? mapaEmpleados[usuarioIncidencia] : null;
                        } else {
                          final usuarioSesion = sesion.entrada?.usuario ?? sesion.salida?.usuario;
                          empleado = usuarioSesion != null ? mapaEmpleados[usuarioSesion] : null;
                        }

                        if (esSoloIncidencia) {
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    empleado != null
                                        ? '${empleado.nombre ?? usuarioIncidencia ?? "Usuario desconocido"} (DNI: ${empleado.dni ?? "N/A"})'
                                        : usuarioIncidencia ?? 'Usuario desconocido',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  ...sesion.incidencias.map((inc) {
                                    final incidenciaCompleta = mapaIncidencias[inc.incidencia.incidenciaCodigo ?? ''];
                                    final computaTexto = incidenciaCompleta?.computa == true ? 'Computa horas' : 'No computa';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Incidencia: ${inc.incidencia.incidenciaCodigo ?? '-'}'
                                              '${inc.incidencia.observaciones != null ? ' (${inc.incidencia.observaciones})' : ''}'
                                              ' — ${inc.contexto}'
                                              ' — $computaTexto',
                                              style: const TextStyle(color: Colors.orange),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        } else {
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

                          String entradaCoords = '-';
                          String salidaCoords = '-';

                          final latE = sesion.entrada?.latitud;
                          final lonE = sesion.entrada?.longitud;
                          if (latE != null && lonE != null) {
                            entradaCoords = '$latE, $lonE';
                          }

                          final latS = sesion.salida?.latitud;
                          final lonS = sesion.salida?.longitud;
                          if (latS != null && lonS != null) {
                            salidaCoords = '$latS, $lonS';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    empleado != null
                                        ? '${empleado.nombre ?? sesion.entrada?.usuario ?? "Usuario desconocido"} (DNI: ${empleado.dni ?? "N/A"})'
                                        : sesion.entrada?.usuario ?? sesion.salida?.usuario ?? 'Usuario desconocido',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Entrada: $entradaStr'),
                                  Text('Salida: $salidaStr'),
                                  Text('Coordenadas entrada: $entradaCoords'),
                                  Text('Coordenadas salida: $salidaCoords'),
                                  if (sesion.incidencias.isNotEmpty)
                                    ...sesion.incidencias.map((inc) {
                                      final incidenciaCompleta = mapaIncidencias[inc.incidencia.incidenciaCodigo ?? ''];
                                      final computaTexto = incidenciaCompleta?.computa == true ? 'Computa horas' : 'No computa';
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Incidencia: ${inc.incidencia.incidenciaCodigo ?? '-'}'
                                                '${inc.incidencia.observaciones != null ? ' (${inc.incidencia.observaciones})' : ''}'
                                                ' — ${inc.contexto}'
                                                ' — $computaTexto',
                                                style: const TextStyle(color: Colors.orange),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  if (tiempoTrabajado.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text('Tiempo trabajado: $tiempoTrabajado',
                                          style: const TextStyle(color: Color.fromARGB(255, 33, 150, 243))),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// Modelos auxiliares
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


// ===== Incidencias Tab =====

class IncidenciasTab extends StatelessWidget {
  const IncidenciasTab({Key? key}) : super(key: key);

  void _abrirDialogo(BuildContext context, AdminProvider provider, {Incidencia? incidencia}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _FormularioIncidencia(
            cifEmpresa: provider.cifEmpresa,
            incidenciaExistente: incidencia,
            onSubmit: (nueva) async {
              String? error;
              if (incidencia == null) {
                error = await provider.addIncidencia(nueva);
              } else {
                if (nueva.codigo == incidencia.codigo &&
                    nueva.descripcion == incidencia.descripcion &&
                    nueva.computa == incidencia.computa) {
                  error = 'No se detectaron cambios para actualizar.';
                } else {
                  error = await provider.updateIncidencia(nueva);
                }
              }
              if (context.mounted) Navigator.pop(context);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: FloatingActionButton.extended(
              icon: const Icon(Icons.add_alert, color: Colors.white),
              label: const Text(
                'Añadir incidencia',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _abrirDialogo(context, provider),
              backgroundColor: kPrimaryBlue,
              elevation: 6,
            ),
          ),
          body: provider.incidencias.isEmpty
              ? const Center(
                  child: Text(
                    'No hay incidencias registradas.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const Divider(height: 16, thickness: 1),
                  itemCount: provider.incidencias.length,
                  itemBuilder: (context, index) {
                    final inc = provider.incidencias[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text('${inc.codigo} - ${inc.descripcion ?? ''}'
                            ' — ${inc.computa ? "Computa horas" : "No computa"}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          tooltip: 'Eliminar incidencia',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirmar borrado'),
                                content: Text('¿Quieres eliminar la incidencia código "${inc.codigo}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final error = await provider.deleteIncidencia(inc.codigo);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () => _abrirDialogo(context, provider, incidencia: inc),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _FormularioIncidencia extends StatefulWidget {
  final String cifEmpresa;
  final Incidencia? incidenciaExistente;
  final void Function(Incidencia incidencia) onSubmit;
  const _FormularioIncidencia({
    required this.cifEmpresa,
    this.incidenciaExistente,
    required this.onSubmit,
  });

  @override
  State<_FormularioIncidencia> createState() => _FormularioIncidenciaState();
}

class _FormularioIncidenciaState extends State<_FormularioIncidencia> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codigoCtrl;
  late TextEditingController _descripcionCtrl;

  bool _computaHoras = true;

  @override
  void initState() {
    super.initState();
    final inc = widget.incidenciaExistente;
    _codigoCtrl = TextEditingController(text: inc?.codigo ?? '');
    _descripcionCtrl = TextEditingController(text: inc?.descripcion ?? '');
    _computaHoras = inc?.computa ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.incidenciaExistente != null;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Editar incidencia' : 'Nueva incidencia',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codigoCtrl,
              decoration: InputDecoration(
                labelText: 'Código',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.code, color: kPrimaryBlue),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Código obligatorio' : null,
              enabled: !isEditing,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionCtrl,
              decoration: InputDecoration(
                labelText: 'Descripción',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.description, color: kPrimaryBlue),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Descripción obligatoria' : null,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('¿Computa horas?'),
              value: _computaHoras,
              onChanged: (bool? value) {
                setState(() {
                  _computaHoras = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSubmit(
                      Incidencia(
                        codigo: _codigoCtrl.text.trim(),
                        descripcion: _descripcionCtrl.text.trim(),
                        cifEmpresa: widget.cifEmpresa,
                        computa: _computaHoras,
                      ),
                    );
                  }
                },
                child: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class HorariosTab extends StatefulWidget {
  const HorariosTab({Key? key}) : super(key: key);

  @override
  State<HorariosTab> createState() => _HorariosTabState();
}

class _HorariosTabState extends State<HorariosTab> {
  String? _dniEmpleadoSeleccionado;

  final List<String> _diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      provider.cargarHorariosEmpresa(provider.cifEmpresa);
    });
  }

  void _abrirDialogoFormulario({HorarioEmpleado? horario}) {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _FormularioHorario(
            cifEmpresa: provider.cifEmpresa,
            empleados: provider.empleados,
            horarioExistente: horario,
            onSubmit: (nuevoHorario) async {
              String? error;
              if (horario == null) {
                error = await provider.addHorarioEmpleado(nuevoHorario);
              } else {
                error = await provider.updateHorarioEmpleado(nuevoHorario);
              }
              if (context.mounted) Navigator.pop(context);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        List<HorarioEmpleado> horariosFiltrados = _dniEmpleadoSeleccionado == null
            ? provider.horarios
            : provider.horarios.where((h) => h.dniEmpleado == _dniEmpleadoSeleccionado).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: DropdownButton<String?>(
                isExpanded: true,
                hint: const Text('Filtrar por empleado'),
                value: _dniEmpleadoSeleccionado,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos los empleados'),
                  ),
                  ...provider.empleados.map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.dni,
                      child: Text(e.nombre ?? e.usuario),
                    ),
                  ),
                ],
                onChanged: (val) async {
                  setState(() => _dniEmpleadoSeleccionado = val);
                  if (val != null) {
                    await provider.cargarHorariosEmpleado(val);
                  } else {
                    await provider.cargarHorariosEmpresa(provider.cifEmpresa);
                  }
                },
              ),
            ),
            Expanded(
              child: horariosFiltrados.isEmpty
                  ? const Center(child: Text('No hay horarios disponibles'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemCount: horariosFiltrados.length,
                      itemBuilder: (context, index) {
                        final horario = horariosFiltrados[index];
                        final empleado = provider.empleados.firstWhere(
                          (e) => e.dni == horario.dniEmpleado,
                          orElse: () => Empleado(
                            usuario: '',
                            dni: horario.dniEmpleado,
                            nombre: '',
                            cifEmpresa: horario.cifEmpresa,
                          ),
                        );
                        final nombreEmpleado = (empleado.nombre?.isNotEmpty ?? false)
                            ? empleado.nombre
                            : empleado.usuario;

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          color: const Color(0xFFF7F0FA),
                          child: ListTile(
                            title: Text(
                              '${_diasSemana[horario.diaSemana]}: ${horario.horaInicio} - ${horario.horaFin}'
                              '${horario.nombreTurno != null && horario.nombreTurno!.isNotEmpty ? ' (${horario.nombreTurno})' : ''}',
                            ),
                            subtitle: Text(
                              'Empleado: $nombreEmpleado (${horario.dniEmpleado})',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _abrirDialogoFormulario(horario: horario),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Confirmar borrado'),
                                        content: Text(
                                          '¿Eliminar horario del día ${_diasSemana[horario.diaSemana]} para empleado con DNI ${horario.dniEmpleado}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final error = await provider.deleteHorarioEmpleado(horario.id!, horario.dniEmpleado);
                                      if (error != null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton.extended(
                  icon: const Icon(Icons.schedule, color: Colors.white),
                  label: const Text(
                    'Añadir horario',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => _abrirDialogoFormulario(),
                  backgroundColor: Colors.blue,
                  elevation: 6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
class _FormularioHorario extends StatefulWidget {
  final String cifEmpresa;
  final List<Empleado> empleados;
  final HorarioEmpleado? horarioExistente;
  final void Function(HorarioEmpleado horario) onSubmit;

  const _FormularioHorario({
    Key? key,
    required this.cifEmpresa,
    required this.empleados,
    this.horarioExistente,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<_FormularioHorario> createState() => _FormularioHorarioState();
}

class _FormularioHorarioState extends State<_FormularioHorario> {
  final _formKey = GlobalKey<FormState>();

  int _diaSemana = 0;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  TextEditingController _nombreTurnoCtrl = TextEditingController();
  String? _dniEmpleadoSeleccionado;

  final List<String> _diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.horarioExistente != null) {
      _diaSemana = widget.horarioExistente!.diaSemana;
      _horaInicio = _parseTime(widget.horarioExistente!.horaInicio);
      _horaFin = _parseTime(widget.horarioExistente!.horaFin);
      _nombreTurnoCtrl.text = widget.horarioExistente?.nombreTurno ?? '';
      _dniEmpleadoSeleccionado = widget.horarioExistente!.dniEmpleado;
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay? tod) {
    if (tod == null) return '';
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickHoraPersonalizada({required bool isInicio}) async {
    final initial = isInicio ? _horaInicio ?? const TimeOfDay(hour: 12, minute: 0) : _horaFin ?? const TimeOfDay(hour: 12, minute: 0);

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            child: _TimePickerWheel(
              initialHour: initial.hour,
              initialMinute: initial.minute,
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        if (isInicio) {
          _horaInicio = result;
        } else {
          _horaFin = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.horarioExistente != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? 'Editar horario' : 'Nuevo horario',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Empleado',
                  border: OutlineInputBorder(),
                ),
                value: _dniEmpleadoSeleccionado,
                items: widget.empleados
                    .map(
                      (empleado) => DropdownMenuItem<String>(
                        value: empleado.dni,
                        child: Text(empleado.nombre ?? empleado.usuario),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _dniEmpleadoSeleccionado = value),
                validator: (value) => value == null ? 'Selecciona un empleado' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Día de la semana',
                  border: OutlineInputBorder(),
                ),
                value: _diaSemana,
                items: List.generate(
                  7,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(_diasSemana[index]),
                  ),
                ),
                onChanged: (v) => setState(() => _diaSemana = v ?? 0),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: () => _pickHoraPersonalizada(isInicio: true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Hora inicio',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(_horaInicio != null ? _formatTime(_horaInicio) : 'Seleccionar hora'),
                ),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: () => _pickHoraPersonalizada(isInicio: false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Hora fin',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(_horaFin != null ? _formatTime(_horaFin) : 'Seleccionar hora'),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nombreTurnoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre turno (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    if (_horaInicio == null || _horaFin == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selecciona hora inicio y hora fin')),
                      );
                      return;
                    }
                    final inicioMinutos = _horaInicio!.hour * 60 + _horaInicio!.minute;
                    final finMinutos = _horaFin!.hour * 60 + _horaFin!.minute;
                    if (inicioMinutos >= finMinutos) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La hora de inicio debe ser anterior a la de fin')),
                      );
                      return;
                    }
                    final nuevoHorario = HorarioEmpleado(
                      id: widget.horarioExistente?.id,
                      dniEmpleado: _dniEmpleadoSeleccionado!,
                      cifEmpresa: widget.cifEmpresa,
                      diaSemana: _diaSemana,
                      horaInicio: _formatTime(_horaInicio),
                      horaFin: _formatTime(_horaFin),
                      nombreTurno: _nombreTurnoCtrl.text.trim(),
                    );
                    widget.onSubmit(nuevoHorario);
                  },
                  child: Text(isEditing ? 'Guardar cambios' : 'Crear horario'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerWheel extends StatefulWidget {
  final int initialHour;
  final int initialMinute;

  const _TimePickerWheel({
    Key? key,
    required this.initialHour,
    required this.initialMinute,
  }) : super(key: key);

  @override
  State<_TimePickerWheel> createState() => _TimePickerWheelState();
}

class _TimePickerWheelState extends State<_TimePickerWheel> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinute = widget.initialMinute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final wheelDiameter = (screenWidth - 80) / 2; // Ajusta según espacios
    const TextStyle textStyle = TextStyle(fontSize: 32);

    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Selecciona la hora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: wheelDiameter,
                height: wheelDiameter,
                child: ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: 50,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedHour = index);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      if (index < 0 || index > 23) return null;
                      final selected = index == _selectedHour;
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: selected
                              ? textStyle.copyWith(color: Colors.black)
                              : textStyle.copyWith(color: Colors.grey),
                        ),
                      );
                    },
                    childCount: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(':', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              SizedBox(
                width: wheelDiameter,
                height: wheelDiameter,
                child: ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: 50,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedMinute = index);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      if (index < 0 || index > 59) return null;
                      final selected = index == _selectedMinute;
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: selected
                              ? textStyle.copyWith(color: Colors.black)
                              : textStyle.copyWith(color: Colors.grey),
                        ),
                      );
                    },
                    childCount: 60,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, TimeOfDay(hour: _selectedHour, minute: _selectedMinute));
                },
                child: const Text('OK'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
