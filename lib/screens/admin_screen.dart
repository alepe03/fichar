import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';


import '../models/empleado.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../db/database_helper.dart';
import '../services/empleado_service.dart';
import '../services/incidencia_service.dart';


const Color kPrimaryBlue = Color.fromARGB(255, 33, 150, 243);

class AdminProvider extends ChangeNotifier {
  List<Empleado> empleados = [];
  List<Historico> historicos = [];
  List<Incidencia> incidencias = [];

  final String cifEmpresa;

  AdminProvider(this.cifEmpresa);

  Future<void> cargarEmpleados() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('empleados', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    empleados = maps.map((m) => Empleado.fromMap(m)).toList();
    notifyListeners();
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
      return respuesta; // Devuelve mensaje de error recibido del servidor
    }

    // Si OK, actualizamos localmente
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'empleados',
      empleado.toMap(),
      where: 'usuario = ? AND cif_empresa = ?',
      whereArgs: [usuarioOriginal, empleado.cifEmpresa],
    );
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

class AdminScreen extends StatefulWidget {
  final String cifEmpresa;
  const AdminScreen({Key? key, required this.cifEmpresa}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      provider.cargarEmpleados();
      provider.cargarHistoricos();
      provider.cargarIncidencias();
    });
  }

  // Quitamos botón de salir, por eso no se necesita esta función.
  // Si quieres, mantén esta función para logout y redirección cuando implementes logout desde otra UI.
  // void _logout(BuildContext context) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.clear();
  //   if (context.mounted) {
  //     Navigator.of(context).pushAndRemoveUntil(
  //       MaterialPageRoute(builder: (_) => const LoginScreen()),
  //       (route) => false,
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Panel de Administración',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 3,
        backgroundColor: kPrimaryBlue,
        // Eliminado botón derecho de salir, acciones vacías
        actions: [],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Usuarios'),
            Tab(text: 'Fichajes'),
            Tab(text: 'Incidencias'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          UsuariosTab(),
          FichajesTab(),
          IncidenciasTab(),
        ],
      ),
    );
  }
}

class UsuariosTab extends StatelessWidget {
  const UsuariosTab({Key? key}) : super(key: key);

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
        return Scaffold(
          backgroundColor: Colors.white,
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 0), // Mueve el botón arriba para que no tape la barra inferior si hay
            child: FloatingActionButton.extended(
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'Añadir usuario',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _abrirDialogo(context, provider),
              backgroundColor: kPrimaryBlue,
              elevation: 6,
            ),
          ),
          body: provider.empleados.isEmpty
              ? const Center(
                  child: Text(
                    'No hay usuarios registrados.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const Divider(height: 16, thickness: 1),
                  itemCount: provider.empleados.length,
                  itemBuilder: (context, index) {
                    final emp = provider.empleados[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(emp.nombre ?? emp.usuario,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                        subtitle: Text('${emp.email ?? 'Sin email'} · Rol: ${emp.rol ?? 'N/D'}',
                            style: const TextStyle(fontSize: 14)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          tooltip: 'Eliminar usuario',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirmar borrado'),
                                content: Text('¿Quieres eliminar al usuario "${emp.usuario}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final error = await provider.deleteEmpleado(emp.usuario);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () => _abrirDialogo(context, provider, empleado: emp),
                      ),
                    );
                  },
                ),
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
  late TextEditingController _passwordHashCtrl;
  final _roles = ['admin', 'empleado'];
  String? _rolSeleccionado;

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
    _passwordHashCtrl = TextEditingController(text: emp?.passwordHash ?? '');
    _rolSeleccionado = emp?.rol;

    _usuarioOriginal = emp?.usuario ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.empleadoExistente != null;
    final theme = Theme.of(context);
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
            TextFormField(
              controller: _usuarioCtrl,
              decoration: InputDecoration(
                labelText: 'Usuario',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, color: kPrimaryBlue),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Usuario obligatorio' : null,
              enabled: true,
            ),
            const SizedBox(height: 12),
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
            TextFormField(
              controller: _direccionCtrl,
              decoration: InputDecoration(
                labelText: 'Dirección',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.home, color: kPrimaryBlue),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _poblacionCtrl,
              decoration: InputDecoration(
                labelText: 'Población',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city, color: kPrimaryBlue),
              ),
            ),
            const SizedBox(height: 12),
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
                      child: Text(r == 'admin' ? 'Administrador' : 'Empleado'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _rolSeleccionado = v),
              validator: (v) => v == null ? 'Selecciona un rol' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordHashCtrl,
              decoration: InputDecoration(
                labelText: 'Hash Password',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock, color: kPrimaryBlue),
              ),
              obscureText: true,
              validator: (v) => v == null || v.isEmpty ? 'Contraseña obligatoria' : null,
            ),
            const SizedBox(height: 24),
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
                        passwordHash: _passwordHashCtrl.text.trim(),
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

  List<SesionTrabajo> _agruparSesiones(List<Historico> registros) {
    List<SesionTrabajo> sesiones = [];
    Historico? entradaPendiente;
    List<IncidenciaEnSesion> incidenciasPendientes = [];

    for (final reg in registros) {
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

    return sesiones.reversed.toList();
  }

  String formatFecha(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '-';
    final dt = DateTime.tryParse(fechaStr);
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<pw.Document> _crearPdf(List<SesionTrabajo> sesiones, Map<String, Empleado> mapaEmpleados) async {
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
                        return '$c${o.isNotEmpty ? ' ($o)' : ''}';
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

  Future<void> _exportarPdfDescargar(List<SesionTrabajo> sesiones, Map<String, Empleado> mapaEmpleados) async {
    try {
      final pdf = await _crearPdf(sesiones, mapaEmpleados);
      final pdfBytes = await pdf.save();
      final rutaGuardado = await _guardarPdfEnDispositivo(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF guardado en: $rutaGuardado')),
        );
      }

      // Abrir el PDF automáticamente después de guardarlo
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
        final sesiones = _agruparSesiones(registrosFiltrados);

        final Map<String, Empleado> mapaEmpleados = {
          for (var e in provider.empleados) e.usuario: e
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
                        onPressed: () => _exportarPdfDescargar(sesiones, mapaEmpleados),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBlue,
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
                                  ...sesion.incidencias.map((inc) => Padding(
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
                                                ' — ${inc.contexto}',
                                                style: const TextStyle(color: Colors.orange),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
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
                                    ...sesion.incidencias.map((inc) => Padding(
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
                                                  ' — ${inc.contexto}',
                                                  style: const TextStyle(color: Colors.orange),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  if (tiempoTrabajado.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text('Tiempo trabajado: $tiempoTrabajado',
                                          style: const TextStyle(color: kPrimaryBlue)),
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
                error = await provider.updateIncidencia(nueva);
              }
              if (context.mounted) Navigator.pop(context);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error al guardar'), backgroundColor: Colors.redAccent),
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
            padding: const EdgeInsets.only(bottom: 0), // Igual que UsuariosTab para evitar tapado
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
                        title: Text('${inc.codigo} - ${inc.descripcion ?? ''}',
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

  @override
  void initState() {
    super.initState();
    final inc = widget.incidenciaExistente;
    _codigoCtrl = TextEditingController(text: inc?.codigo ?? '');
    _descripcionCtrl = TextEditingController(text: inc?.descripcion ?? '');
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
