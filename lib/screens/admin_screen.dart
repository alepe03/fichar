import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/empleado.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../db/database_helper.dart';
import '../services/empleado_service.dart';
import '../services/incidencia_service.dart';
import 'login_screen.dart';

// Pantalla de administración principal con pestañas para usuarios, fichajes e incidencias
// Usa Provider para gestionar el estado y la recarga de datos

// ----------------- PROVIDER -----------------
// AdminProvider gestiona los datos y operaciones CRUD de empleados, fichajes e incidencias
class AdminProvider extends ChangeNotifier {
  List<Empleado> empleados = [];     // Lista de empleados cargados
  List<Historico> historicos = [];   // Lista de fichajes cargados
  List<Incidencia> incidencias = []; // Lista de incidencias cargadas

  final String cifEmpresa;           // CIF de la empresa actual

  AdminProvider(this.cifEmpresa);

  // --- CARGA DATOS ---
  // Carga empleados desde la base de datos local
  Future<void> cargarEmpleados() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('empleados', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    empleados = maps.map((m) => Empleado.fromMap(m)).toList();
    notifyListeners();
  }

  // Carga fichajes desde la base de datos local
  Future<void> cargarHistoricos() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('historico', where: 'cif_empresa = ?', whereArgs: [cifEmpresa]);
    historicos = maps.map((m) => Historico.fromMap(m)).toList();
    notifyListeners();
  }

  // Carga incidencias desde la base de datos local
  Future<void> cargarIncidencias() async {
    incidencias = await IncidenciaService.cargarIncidenciasLocal(cifEmpresa);
    notifyListeners();
  }

  // --- CRUD EMPLEADOS ---
  // Añade un empleado tanto en remoto como en local
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

  // Actualiza un empleado en local (requiere usuario original)
  Future<String?> updateEmpleado(Empleado empleado, String usuarioOriginal) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'empleados',
      empleado.toMap(),
      where: 'usuario = ? AND cif_empresa = ?',
      whereArgs: [usuarioOriginal, empleado.cifEmpresa],
    );
    await cargarEmpleados();
    return null;
  }

  // Elimina un empleado tanto en remoto como en local
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

  // --- CRUD INCIDENCIAS ---
  // Añade una incidencia tanto en remoto como en local
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

  // Actualiza una incidencia tanto en remoto como en local
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

  // Elimina una incidencia tanto en remoto como en local
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

// ----------------- SCREEN PRINCIPAL -----------------
// Pantalla principal con pestañas para Usuarios, Fichajes e Incidencias
class AdminScreen extends StatefulWidget {
  final String cifEmpresa;
  const AdminScreen({Key? key, required this.cifEmpresa}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  // Controlador de pestañas
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Carga los datos al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      provider.cargarEmpleados();
      provider.cargarHistoricos();
      provider.cargarIncidencias();
    });
  }

  // Cierra sesión y vuelve a la pantalla de login
  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          // Botón para cerrar sesión
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
            onPressed: () => _logout(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Usuarios'),
            Tab(text: 'Fichajes'),
            Tab(text: 'Incidencias'),
          ],
        ),
      ),
      // Cuerpo con las tres pestañas
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

// ----------------- TAB USUARIOS -----------------
// Pestaña para ver, añadir, editar y borrar empleados
class UsuariosTab extends StatelessWidget {
  const UsuariosTab({Key? key}) : super(key: key);

  void _abrirDialogo(BuildContext context, AdminProvider provider, {Empleado? empleado}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
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
          floatingActionButton: FloatingActionButton(
            onPressed: () => _abrirDialogo(context, provider),
            child: const Icon(Icons.add),
            tooltip: 'Añadir empleado',
          ),
          body: provider.empleados.isEmpty
              ? const Center(child: Text('No hay usuarios.'))
              : ListView.builder(
                  itemCount: provider.empleados.length,
                  itemBuilder: (context, index) {
                    final emp = provider.empleados[index];
                    return ListTile(
                      title: Text(emp.nombre ?? emp.usuario),
                      subtitle: Text('${emp.email ?? ''} (${emp.rol ?? ''})'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('¿Borrar usuario?'),
                              content: Text('¿Seguro que quieres borrar "${emp.usuario}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final error = await provider.deleteEmpleado(emp.usuario);
                            if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () => _abrirDialogo(context, provider, empleado: emp),
                    );
                  },
                ),
        );
      },
    );
  }
}

// ----------------- FORMULARIO ALTA/EDICIÓN EMPLEADO -----------------
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
  final _rols = ['admin', 'empleado'];
  String? _rolSeleccionado;

  // Variable para guardar usuario original
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
    final esEdicion = widget.empleadoExistente != null;
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              esEdicion ? 'Editar empleado' : 'Nuevo empleado',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usuarioCtrl,
              decoration: const InputDecoration(labelText: 'Usuario'),
              validator: (v) => v == null || v.isEmpty ? 'Usuario obligatorio' : null,
              enabled: true, // ahora siempre editable
            ),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => v == null || v.isEmpty ? 'Nombre obligatorio' : null,
            ),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextFormField(
              controller: _direccionCtrl,
              decoration: const InputDecoration(labelText: 'Dirección'),
            ),
            TextFormField(
              controller: _poblacionCtrl,
              decoration: const InputDecoration(labelText: 'Población'),
            ),
            TextFormField(
              controller: _codigoPostalCtrl,
              decoration: const InputDecoration(labelText: 'Código Postal'),
            ),
            TextFormField(
              controller: _telefonoCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            TextFormField(
              controller: _dniCtrl,
              decoration: const InputDecoration(labelText: 'DNI'),
              validator: (v) => v == null || v.isEmpty ? 'DNI obligatorio' : null,
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Rol'),
              value: _rolSeleccionado,
              items: _rols
                  .map((r) => DropdownMenuItem(value: r, child: Text(r == 'admin' ? 'Administrador' : 'Empleado')))
                  .toList(),
              onChanged: (v) => setState(() => _rolSeleccionado = v),
              validator: (v) => v == null ? 'Selecciona un rol' : null,
            ),
            TextFormField(
              controller: _passwordHashCtrl,
              decoration: const InputDecoration(labelText: 'Hash Password'),
              validator: (v) => v == null || v.isEmpty ? 'Contraseña obligatoria' : null,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSubmit(
                    Empleado(
                      usuario: _usuarioCtrl.text,
                      cifEmpresa: widget.cifEmpresa,
                      direccion: _direccionCtrl.text,
                      poblacion: _poblacionCtrl.text,
                      codigoPostal: _codigoPostalCtrl.text,
                      telefono: _telefonoCtrl.text,
                      email: _emailCtrl.text,
                      nombre: _nombreCtrl.text,
                      dni: _dniCtrl.text,
                      rol: _rolSeleccionado,
                      passwordHash: _passwordHashCtrl.text,
                    ),
                    _usuarioOriginal, // paso usuario original para update
                  );
                }
              },
              child: Text(esEdicion ? 'Guardar cambios' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- TAB FICHAJES -----------------
// Pestaña para ver el histórico de fichajes de la empresa
class FichajesTab extends StatelessWidget {
  const FichajesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        if (provider.historicos.isEmpty) {
          return const Center(child: Text('No hay fichajes.'));
        }
        return ListView.builder(
          itemCount: provider.historicos.length,
          itemBuilder: (context, index) {
            final hist = provider.historicos[index];
            return ListTile(
              title: Text('Usuario: ${hist.usuario}'),
              subtitle: Text('Entrada: ${hist.fechaEntrada} - Salida: ${hist.fechaSalida ?? "-"}'),
            );
          },
        );
      },
    );
  }
}

// ----------------- TAB INCIDENCIAS -----------------
// Pestaña para ver, añadir, editar y borrar incidencias
class IncidenciasTab extends StatelessWidget {
  const IncidenciasTab({Key? key}) : super(key: key);

  void _abrirDialogo(BuildContext context, AdminProvider provider, {Incidencia? incidencia}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
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
          floatingActionButton: FloatingActionButton(
            onPressed: () => _abrirDialogo(context, provider),
            child: const Icon(Icons.add),
            tooltip: 'Añadir incidencia',
          ),
          body: provider.incidencias.isEmpty
              ? const Center(child: Text('No hay incidencias.'))
              : ListView.builder(
                  itemCount: provider.incidencias.length,
                  itemBuilder: (context, index) {
                    final inc = provider.incidencias[index];
                    return ListTile(
                      title: Text('${inc.codigo} - ${inc.descripcion ?? ""}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('¿Borrar incidencia?'),
                              content: Text('¿Seguro que quieres borrar la incidencia código "${inc.codigo}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final error = await provider.deleteIncidencia(inc.codigo);
                            if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () => _abrirDialogo(context, provider, incidencia: inc),
                    );
                  },
                ),
        );
      },
    );
  }
}

// -------------- FORMULARIO ALTA/EDICIÓN INCIDENCIA --------------
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
    final esEdicion = widget.incidenciaExistente != null;
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              esEdicion ? 'Editar incidencia' : 'Nueva incidencia',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(labelText: 'Código'),
              validator: (v) => v == null || v.isEmpty ? 'Código obligatorio' : null,
              enabled: !esEdicion, // No editable en edición
            ),
            TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (v) => v == null || v.isEmpty ? 'Descripción obligatoria' : null,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSubmit(
                    Incidencia(
                      codigo: _codigoCtrl.text,
                      descripcion: _descripcionCtrl.text,
                      cifEmpresa: widget.cifEmpresa,
                    ),
                  );
                }
              },
              child: Text(esEdicion ? 'Guardar cambios' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
