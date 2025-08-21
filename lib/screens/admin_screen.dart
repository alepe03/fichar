import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';


import '../models/empleado.dart';
import '../models/historico.dart';
import '../models/incidencia.dart';
import '../providers/admin_provider.dart';
import '../models/horario_empleado.dart';
import '../screens/map_view_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';


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
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _isLoading = true);
      final provider = Provider.of<AdminProvider>(context, listen: false);
      await provider.cargarDatosIniciales();
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
          isScrollable: false,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Usuarios'),
            Tab(text: 'Fichajes'),
            Tab(text: 'Incidencias'),
            Tab(text: 'Horarios'),
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
                HorariosTab(),
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

  // Helper para mostrar el rol con etiqueta humana
  String _rolLabel(String? rol) {
    switch (rol) {
      case 'admin':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'terminal_fichaje':
        return 'Terminal de fichaje';
      case 'empleado':
        return 'Empleado';
      default:
        return 'N/D';
    }
  }

  // === GENERACIÓN DEL QR Y PDF ===

  Future<dynamic> generarPdfQrEmpleado(Empleado emp) async {
    final id = emp.id.toString();
    final pin = emp.pinFichaje ?? '0000';
    final qrData = '$id;$pin'; // <- QR en formato plano

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('QR de Fichaje', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Nombre: ${emp.nombre ?? ''}'),
            pw.Text('Usuario: ${emp.usuario}'),
            pw.Text('ID: $id'),
            pw.SizedBox(height: 20),
            pw.BarcodeWidget(
              data: qrData,
              barcode: pw.Barcode.qrCode(),
              width: 180,
              height: 180,
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Escanea este código con la app de fichaje para iniciar sesión.',
              style: pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) {
      // En web, generar el PDF y mostrar mensaje de éxito
      // El usuario puede usar la función de descarga del navegador
      final bytes = await pdf.save();
      // En web, solo retornamos los bytes para que se puedan descargar
      return bytes;
    } else {
      // En móvil/desktop, usar path_provider como antes
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/qr_fichaje_${emp.usuario}.pdf");
      await file.writeAsBytes(await pdf.save());
      return file;
    }
  }

  Future<void> _generarYMostrarQR(BuildContext context, Empleado emp) async {
    try {
      if (kIsWeb) {
        // En web, generar y descargar automáticamente
        final result = await generarPdfQrEmpleado(emp);
        if (result is List<int>) {
          // Crear un blob y descargarlo
          _downloadPdfWeb(result, 'qr_fichaje_${emp.usuario}.pdf');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF con QR generado y descargado. Puedes enviarlo por email al empleado.')),
            );
          }
        }
      } else {
        // En móvil/desktop, generar y abrir
        final file = await generarPdfQrEmpleado(emp);
        await OpenFile.open(file.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF con QR generado. Puedes enviarlo por email al empleado.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generando QR: $e'), backgroundColor: Colors.redAccent),
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

  void _abrirDialogo(BuildContext context, AdminProvider provider, {Empleado? empleado}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFFEAEAEA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _FormularioEmpleado(
            cifEmpresa: provider.cifEmpresa,
            empleadoExistente: empleado,
            maxUsuariosActivos: provider.maxUsuariosActivos,    // <-- pasa el max (puede ser null)
            activosQueCuentan: provider.activosQueCuentan,      // <-- pasa los activos que cuentan (excluye supervisor)
            onSubmit: (nuevo, usuarioOriginal) async {
              // Seguridad extra por si toquetean el cliente:
              const rolesPermitidosAdmin = ['empleado', 'supervisor', 'terminal_fichaje'];
              if (nuevo.rol != 'admin' && !rolesPermitidosAdmin.contains(nuevo.rol)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rol no permitido. Solo Empleado, Supervisor o Terminal de fichaje.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }

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

        // Activos X/Y (X excluye supervisor; Y puede ser null)
        final int activosQueCuentan = provider.activosQueCuentan;
        final int? maxUsuariosActivos = provider.maxUsuariosActivos;

        return Column(
          children: [
            if (maxUsuariosActivos != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  avatar: const Icon(Icons.people_alt, size: 18, color: Colors.white),
                  label: Text(
                    'Activos $activosQueCuentan/$maxUsuariosActivos',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: kPrimaryBlue,
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: filtro == FiltroEstado.todos,
                    onSelected: (_) => setState(() => filtro = FiltroEstado.todos),
                    backgroundColor: const Color(0xFFEAEAEA),
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: filtro == FiltroEstado.todos ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Activos'),
                    selected: filtro == FiltroEstado.activos,
                    onSelected: (_) => setState(() => filtro = FiltroEstado.activos),
                    backgroundColor: const Color(0xFFEAEAEA),
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: filtro == FiltroEstado.activos ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Inactivos'),
                    selected: filtro == FiltroEstado.inactivos,
                    onSelected: (_) => setState(() => filtro = FiltroEstado.inactivos),
                    backgroundColor: const Color(0xFFEAEAEA),
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: filtro == FiltroEstado.inactivos ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
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
                          color: const Color(0xFFEAEAEA),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(emp.nombre ?? emp.usuario,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                            subtitle: Text(
                                '${emp.email ?? "Sin email"} · Rol: ${_rolLabel(emp.rol)} · Estado: ${emp.activo == 1 ? "Activo" : "Inactivo"}',
                                style: const TextStyle(fontSize: 14)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    emp.activo == 1 ? Icons.check_circle : Icons.block,
                                    color: emp.activo == 1 ? Colors.green : Colors.red,
                                  ),
                                  tooltip: emp.activo == 1 ? 'Dar de baja' : 'Reactivar usuario',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: const Color(0xFFEAEAEA),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: Text(
                                          emp.activo == 1 ? 'Confirmar baja' : 'Confirmar reactivación',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                        ),
                                        content: Text(
                                          emp.activo == 1
                                              ? '¿Quieres dar de baja al usuario "${emp.usuario}"?'
                                              : '¿Quieres reactivar al usuario "${emp.usuario}"?',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        actionsAlignment: MainAxisAlignment.spaceBetween,
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancelar', style: TextStyle(color: Colors.blue)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            ),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Confirmar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final quiereActivar = emp.activo == 0;
                                      final rolCuenta = (emp.rol != 'supervisor');
                                      final bool sinPlazas = (maxUsuariosActivos != null) &&
                                          rolCuenta &&
                                          quiereActivar &&
                                          (activosQueCuentan >= maxUsuariosActivos);

                                      if (sinPlazas) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('No quedan plazas activas en el plan de la empresa.'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                        return; // no disparamos update
                                      }

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
                                // ==== Botón de QR ====
                                IconButton(
                                  icon: const Icon(Icons.qr_code, color: Colors.blueAccent),
                                  tooltip: 'Generar QR y abrir PDF',
                                  onPressed: () async {
                                    await _generarYMostrarQR(context, emp);
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

  // NUEVOS: para UX de plazas
  final int? maxUsuariosActivos;
  final int activosQueCuentan;

  const _FormularioEmpleado({
    required this.cifEmpresa,
    this.empleadoExistente,
    required this.onSubmit,
    this.maxUsuariosActivos,
    this.activosQueCuentan = 0,
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

  // === Cambios clave ===
  // Lista de roles permitidos cuando el ADMIN crea/edita usuarios que NO son admin.
  final List<String> _rolesPermitidosAdmin = const ['empleado', 'supervisor', 'terminal_fichaje'];

  String? _rolSeleccionado;
  bool _puedeLocalizar = false;
  bool _activo = true;

  late String _usuarioOriginal;
  late bool _isEditing;
  late bool _editaUnAdmin; // si el usuario existente es admin

  // Helper etiqueta humana
  String _rolLabel(String? rol) {
    switch (rol) {
      case 'admin':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'terminal_fichaje':
        return 'Terminal de fichaje';
      case 'empleado':
        return 'Empleado';
      default:
        return 'N/D';
    }
  }

  @override
  void initState() {
    super.initState();
    final emp = widget.empleadoExistente;
    _isEditing = emp != null;
    _editaUnAdmin = (emp?.rol == 'admin');

    _usuarioCtrl = TextEditingController(text: emp?.usuario ?? '');
    _nombreCtrl = TextEditingController(text: emp?.nombre ?? '');
    _emailCtrl = TextEditingController(text: emp?.email ?? '');
    _direccionCtrl = TextEditingController(text: emp?.direccion ?? '');
    _poblacionCtrl = TextEditingController(text: emp?.poblacion ?? '');
    _codigoPostalCtrl = TextEditingController(text: emp?.codigoPostal ?? '');
    _telefonoCtrl = TextEditingController(text: emp?.telefono ?? '');
    _dniCtrl = TextEditingController(text: emp?.dni ?? '');
    _passwordCtrl = TextEditingController(text: emp != null ? '******' : '');

    // Si edita un admin, bloqueamos el cambio de rol y lo mostramos fijo
    if (_editaUnAdmin) {
      _rolSeleccionado = 'admin';
    } else {
      // En creación o edición de no-admin, por defecto primer rol permitido
      _rolSeleccionado = emp?.rol != null && _rolesPermitidosAdmin.contains(emp!.rol)
          ? emp.rol
          : _rolesPermitidosAdmin.first;
    }

    _puedeLocalizar = (emp?.puedeLocalizar ?? 0) == 1;
    _activo = (emp?.activo ?? 1) == 1;
    _usuarioOriginal = emp?.usuario ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool rolCuenta = (_rolSeleccionado != 'supervisor');
    final bool hayMax = widget.maxUsuariosActivos != null;

    // No hay plazas si: hay max definido, el rol cuenta, el registro está INACTIVO ahora
    // (porque al togglear a true estaríamos intentando ocupar plaza), y X>=Y.
    final bool sinPlazasAlActivar =
        hayMax && rolCuenta && (_activo == false) && (widget.activosQueCuentan >= widget.maxUsuariosActivos!);

    return Container(
      color: const Color(0xFFEAEAEA),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEditing ? 'Editar empleado' : 'Nuevo empleado',
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
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email obligatorio';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Introduce un email válido';
                  }
                  return null;
                },
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
              enabled: !_isEditing,
              validator: (v) {
                if (!_isEditing && (v == null || v.isEmpty)) {
                  return 'Contraseña obligatoria';
                }
                return null;
              },
            ),
              const SizedBox(height: 12),

              // Rol (bloqueado si edita un admin; si no, limitado a los 3 permitidos)
              if (_editaUnAdmin)
                TextFormField(
                  enabled: false,
                  initialValue: _rolLabel('admin'),
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security, color: kPrimaryBlue),
                  ),
                )
              else
                              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security, color: kPrimaryBlue),
                ),
                value: _rolSeleccionado,
                items: _rolesPermitidosAdmin
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _rolLabel(r),
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final bool nuevoRolCuenta = v != 'supervisor';
                  // Si estoy EDITANDO, el usuario está ACTIVO, el rol actual es supervisor,
                  // y quiero pasarlo a un rol que cuenta, pero no hay plazas => bloqueo.
                  final bool noQuedanPlazasParaCambioDeRol =
                      _isEditing &&
                      _activo &&
                      (_rolSeleccionado == 'supervisor') &&
                      nuevoRolCuenta &&
                      (widget.maxUsuariosActivos != null) &&
                      (widget.activosQueCuentan >= widget.maxUsuariosActivos!);

                  if (noQuedanPlazasParaCambioDeRol) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No quedan plazas activas en el plan para cambiar el rol.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return; // no cambiamos el rol en UI
                  }

                  setState(() {
                    _rolSeleccionado = v;
                    if (v == 'supervisor') {
                      _puedeLocalizar = false;
                    }
                  });
                },
                validator: (v) => v == null ? 'Selecciona un rol' : null,
                dropdownColor: Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                menuMaxHeight: 200,
              ),

              const SizedBox(height: 12),

              // Switches
              SwitchListTile(
                title: const Text('Permitir localización'),
                value: _puedeLocalizar,
                activeColor: Colors.blue,
                onChanged: (_rolSeleccionado != 'supervisor')
                    ? (value) {
                        setState(() {
                          _puedeLocalizar = value;
                        });
                      }
                    : null,
              ),

              // Empleado activo (con control de plazas locales)
              SwitchListTile(
                title: const Text('Empleado activo'),
                value: _activo,
                activeColor: Colors.blue,
                subtitle: sinPlazasAlActivar
                    ? const Text('Sin plazas activas disponibles en el plan', style: TextStyle(color: Colors.redAccent))
                    : null,
                onChanged: (value) {
                  // Si queremos activar (value==true) y no hay plazas, lo bloqueamos.
                  if (value && sinPlazasAlActivar) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No quedan plazas activas en el plan de la empresa.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
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
                      final rolParaGuardar = _editaUnAdmin ? 'admin' : _rolSeleccionado;

                      // Defensa adicional en cliente
                      if (!_editaUnAdmin && !_rolesPermitidosAdmin.contains(rolParaGuardar)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rol no permitido. Solo Empleado, Supervisor o Terminal de fichaje.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

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
                          rol: rolParaGuardar,
                          passwordHash: _isEditing ? '' : _passwordCtrl.text.trim(),
                          puedeLocalizar: _puedeLocalizar ? 1 : 0,
                          activo: _activo ? 1 : 0,
                        ),
                        _usuarioOriginal,
                      );
                    }
                  },
                  child: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// FichajesTab.dart
/// Agregado por usuario para el resumen
class _Agg {
  int trabajadas = 0; // minutos
  int ordinarias = 0; // minutos
  final Set<DateTime> diasContados = {}; // para no duplicar ordinarias por día
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

  // --- Config: tu BD usa 0..6 con 0=Lunes -> deja esto en false
  static const bool kMondayIs1 = false; // FIX

  // ------------------ UI helpers ------------------
  List<DropdownMenuItem<int>> _buildYears() {
    // Años fijos desde 2024 hasta 2028
    final years = [2024, 2025, 2026, 2027, 2028];
    return years.map((y) => DropdownMenuItem<int>(
      value: y, 
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$y',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    )).toList();
  }

  List<DropdownMenuItem<int>> _buildMonths() {
    return List.generate(12, (i) => i + 1)
        .map((m) => DropdownMenuItem<int>(
          value: m, 
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              m.toString().padLeft(2, '0'),
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ))
        .toList();
  }

  List<DropdownMenuItem<String?>> _buildUsuarios(List<Empleado> empleados) {
    return [
      DropdownMenuItem<String?>(
        value: null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Todos los empleados',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
      ...empleados.map(
        (e) => DropdownMenuItem<String?>(
          value: e.usuario,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              e.nombre ?? e.usuario,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ------------------ Datos / filtros ------------------
  List<Historico> _filtrarRegistros(List<Historico> registros) {
    return registros.where((reg) {
      if (_selectedUsuario != null && reg.usuario != _selectedUsuario) return false;
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
                entrada: null,
                salida: null,
                incidencias: [IncidenciaEnSesion(reg, contexto)]));
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

  int _weekdayToDiaSemana(DateTime d) {
    // DateTime.weekday: 1=Mon..7=Sun
    if (kMondayIs1) {
      return d.weekday; // 1..7 (1=Lunes)
    } else {
      // FIX: BD 0..6 (0=Lunes) => rotate-left
      // 1(Lun)->0, 2(Mar)->1, ..., 7(Dom)->6
      return (d.weekday + 6) % 7;
    }
  }

  DateTime? _parse(String? s) =>
      (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

  // ------------------ Horas ordinarias (lookup) ------------------
  /// (dni, diaSemana) -> minutos ordinarios del día (sumados si hay varios turnos)
  Map<String, Map<int, int>> _buildOrdinariasIndex(
      List<HorarioEmpleado> horarios) {
    final Map<String, Map<int, int>> idx = {};
    for (final h in horarios) {
      if (h.dniEmpleado.isEmpty) continue;
      final dni = h.dniEmpleado;
      final ds = h.diaSemana;
      final min =
          h.horasOrdinariasMin ?? _tryParseHHmmToMinutes(h.horasOrdinarias);
      if (min == null) continue;

      idx.putIfAbsent(dni, () => {});
      idx[dni]!.update(ds, (v) => v + min, ifAbsent: () => min);
    }
    return idx;
  }

  // FIX: tolera HH:MM y HH:MM:SS
  int? _tryParseHHmmToMinutes(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Devuelve minutos ordinarios para un dni y fecha
  int? _ordinariasForDay(
      Map<String, Map<int, int>> idx, String dni, DateTime fecha) {
    final ds = _weekdayToDiaSemana(fecha);
    final byDni = idx[dni];
    if (byDni == null) return null;
    return byDni[ds];
  }

  // ------------------ PDF ------------------
  Future<pw.Document> _crearPdf({
    required List<SesionTrabajo> sesiones,
    required Map<String, Empleado> mapaEmpleados,
    required Map<String, Incidencia> mapaIncidencias,
    required List<HorarioEmpleado> horarios,
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

    // Índice de ordinarias
    final ordinariasIdx = _buildOrdinariasIndex(horarios);

    // Cabecera de documento
    final titulo =
        'Fichajes ${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}'
        '${_selectedUsuario != null ? ' · ${_selectedUsuario}' : ''}';

    // Cabeceras tabla principal
    final headers = [
      'Empleado',
      'DNI',
      'Entrada',
      'Salida',
      'Coordenadas Entrada',
      'Coordenadas Salida',
      'Tiempo',
      'Horas ordinarias',
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

        final entradaCoords = (sesion.entrada?.latitud != null &&
                sesion.entrada?.longitud != null)
            ? '${sesion.entrada!.latitud}, ${sesion.entrada!.longitud}'
            : '-';

        final salidaCoords = (sesion.salida?.latitud != null &&
                sesion.salida?.longitud != null)
            ? '${sesion.salida!.latitud}, ${sesion.salida!.longitud}'
            : '-';

        // Tiempo trabajado (min)
        int minutosTrabajados = 0;
        final dtE = _parse(sesion.entrada?.fechaEntrada);
        final dtS = _parse(sesion.salida?.fechaSalida);
        if (dtE != null && dtS != null) {
          minutosTrabajados = _diffMinutos(dtE, dtS);
        }
        final tiempoTrabajadoStr =
            minutosTrabajados > 0 ? '${_formatMinutos(minutosTrabajados)} h' : '-';

        // Horas ordinarias (por día de ENTRADA)
        String horasOrdinariasStr = '-';
        if (dtE != null) {
          final dni = empleado?.dni ??
              sesion.entrada?.dniEmpleado ??
              sesion.salida?.dniEmpleado;
          if (dni != null && dni.isNotEmpty) {
            final mo = _ordinariasForDay(ordinariasIdx, dni, dtE);
            if (mo != null && mo > 0) horasOrdinariasStr = '${_formatMinutos(mo)} h';
          }
        }

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
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(entradaCoords)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(salidaCoords)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(tiempoTrabajadoStr)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(horasOrdinariasStr)),
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

    // --------- Resumen por empleado ---------
    final Map<String /*usuario*/, _Agg> agg = {};
    for (final sesion in sesiones) {
      final usuario = sesion.entrada?.usuario ??
          sesion.salida?.usuario ??
          (sesion.incidencias.isNotEmpty
              ? sesion.incidencias.first.incidencia.usuario
              : null);
      if (usuario == null) continue;

      final a = agg.putIfAbsent(usuario, () => _Agg());

      final dtE = _parse(sesion.entrada?.fechaEntrada);
      final dtS = _parse(sesion.salida?.fechaSalida);

      if (dtE != null && dtS != null) {
        a.trabajadas += _diffMinutos(dtE, dtS);
      }

      // ordinarias: 1 vez por día (clave = ENTRADA)
      if (dtE != null) {
        final dayKey = DateTime(dtE.year, dtE.month, dtE.day);
        if (!a.diasContados.contains(dayKey)) {
          final dni = mapaEmpleados[usuario]?.dni ??
              sesion.entrada?.dniEmpleado ??
              sesion.salida?.dniEmpleado;
          if (dni != null && dni.isNotEmpty) {
            final mo = _ordinariasForDay(ordinariasIdx, dni, dtE);
            if (mo != null && mo > 0) a.ordinarias += mo;
          }
          a.diasContados.add(dayKey);
        }
      }
    }

    final totalTrabMin = agg.values.fold(0, (p, e) => p + e.trabajadas);
    final totalOrdMin = agg.values.fold(0, (p, e) => p + e.ordinarias);

    List<pw.TableRow> buildResumenRows() {
      final rows = <pw.TableRow>[];
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: azul),
          children: [
            _cellHeader('Empleado', blanco),
            _cellHeader('DNI', blanco),
            _cellHeader('Ordinarias (mes)', blanco),
            _cellHeader('Trabajadas (mes)', blanco),
            _cellHeader('Δ', blanco),
          ],
        ),
      );

      int i = 0;
      // Orden estable por nombre para que no baile
      final empleadosOrdenados = mapaEmpleados.entries.toList()
        ..sort((a, b) => (a.value.nombre ?? a.key).compareTo(
              b.value.nombre ?? b.key,
            ));

      for (final entry in empleadosOrdenados) {
        final usuario = entry.key;
        final emp = entry.value;
        final a = agg[usuario];
        if (a == null) continue;

        final rowColor =
            (i++ % 2 == 0) ? null : const pw.BoxDecoration(color: azulClaro);
        final delta = a.trabajadas - a.ordinarias;

        rows.add(
          pw.TableRow(
            decoration: rowColor,
            children: [
              _cellBody(emp.nombre ?? usuario),
              _cellBody(emp.dni ?? '-'),
              _cellBody('${_formatMinutos(a.ordinarias)} h'),
              _cellBody('${_formatMinutos(a.trabajadas)} h'),
              _cellBody('${_formatMinutos(delta)} h'),
            ],
          ),
        );
      }

      // Totales
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: azulClaro),
          children: [
            _cellBodyBold('Totales'),
            _cellBodyBold(''),
            _cellBodyBold('${_formatMinutos(totalOrdMin)} h'),
            _cellBodyBold('${_formatMinutos(totalTrabMin)} h'),
            _cellBodyBold(
                '${_formatMinutos(totalTrabMin - totalOrdMin)} h'),
          ],
        ),
      );

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
                  'Fichajes filtrados',
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
              4: pw.FlexColumnWidth(1.2), // Coords E
              5: pw.FlexColumnWidth(1.2), // Coords S
              6: pw.FlexColumnWidth(0.8), // Tiempo
              7: pw.FlexColumnWidth(0.9), // Ordinarias
              8: pw.FlexColumnWidth(1.4), // Incidencias
            },
            children: buildMainTableRows(),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Resumen de horas',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(1.0),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(0.6),
            },
            children: buildResumenRows(),
          ),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _cellHeader(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: color,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9.5)),
      );

  static pw.Widget _cellBody(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)));

  static pw.Widget _cellBodyBold(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style:
              pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));

  // ------------------ Guardado ------------------
  Future<dynamic> _guardarPdfEnDispositivo(Uint8List pdfBytes) async {
    if (kIsWeb) {
      // En web, retornar los bytes para descarga
      return pdfBytes;
    } else {
      // En móvil/desktop, usar path_provider como antes
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'fichajes_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${_selectedUsuario ?? 'todos'}.pdf';
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
    List<HorarioEmpleado> horarios,
  ) async {
    try {
      // Usar datos locales para asegurar que las incidencias tengan toda la información
      final provider = context.read<AdminProvider>();
      final fichajesLocales = await provider.obtenerFichajesLocales();
      final registrosFiltrados = _filtrarRegistros(fichajesLocales);
      final sesionesLocales = _agruparSesionesPorUsuario(registrosFiltrados);

      final pdf = await _crearPdf(
        sesiones: sesionesLocales,
        mapaEmpleados: mapaEmpleados,
        mapaIncidencias: mapaIncidencias,
        horarios: horarios,
      );
      final pdfBytes = await pdf.save();
      final resultado = await _guardarPdfEnDispositivo(pdfBytes);

      if (kIsWeb) {
        // En web, descargar automáticamente
        if (resultado is Uint8List) {
          _downloadPdfWeb(resultado, 'fichajes_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${_selectedUsuario ?? 'todos'}.pdf');
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

  // ------------------ Build (UI: SOLO ESTÉTICA MEJORADA) ------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        if (provider.historicos.isEmpty) {
          return const Center(
            child: Text('No hay fichajes.',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
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

        // ⚠️ lista real de horarios
        final List<HorarioEmpleado> horarios = provider.horarios;
        final ordinariasIdx = _buildOrdinariasIndex(horarios);

        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Filtro de Año - Compacto
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade600),
                            const SizedBox(width: 6),
                            DropdownButton<int>(
                              value: _selectedYear,
                              items: _buildYears(),
                              onChanged: (v) => setState(() => _selectedYear = v!),
                              underline: const SizedBox(),
                              icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade600, size: 18),
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              dropdownColor: Colors.white,
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              menuMaxHeight: 200,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Filtro de Mes - Compacto
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.date_range, size: 16, color: Colors.blue.shade600),
                            const SizedBox(width: 6),
                            DropdownButton<int>(
                              value: _selectedMonth,
                              items: _buildMonths(),
                              onChanged: (v) => setState(() => _selectedMonth = v!),
                              underline: const SizedBox(),
                              icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade600, size: 18),
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              dropdownColor: Colors.white,
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              menuMaxHeight: 200,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Filtro de Empleado - Compacto
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 16, color: Colors.blue.shade600),
                              const SizedBox(width: 6),
                              Expanded(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  value: _selectedUsuario,
                                  items: _buildUsuarios(provider.empleados),
                                  onChanged: (v) => setState(() => _selectedUsuario = v),
                                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade600, size: 18),
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  dropdownColor: Colors.white,
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  menuMaxHeight: 200,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Exportar PDF'),
                        onPressed: () => _exportarPdfDescargar(
                            sesiones, mapaEmpleados, mapaIncidencias, horarios),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

                        final eLat = s.entrada?.latitud,
                            eLon = s.entrada?.longitud;
                        final entradaCoords =
                            (eLat != null && eLon != null) ? '$eLat, $eLon' : '-';

                        final sLat = s.salida?.latitud,
                            sLon = s.salida?.longitud;
                        final salidaCoords =
                            (sLat != null && sLon != null) ? '$sLat, $sLon' : '-';

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
                          final mo = _ordinariasForDay(ordinariasIdx, dni, dtE);
                          if (mo != null && mo > 0) {
                            ordStr = _formatMinutos(mo);
                          }
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
                          coordsEntrada: entradaCoords,
                          coordsSalida: salidaCoords,
                          tiempo: tiempoStr,
                          ordinarias: ordStr,
                          incidencias: incidenciasText,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}



// ====== UI: Tarjeta compacta y moderna por sesión (SOLO FICHAJES) ======
class _SessionCompactCard extends StatelessWidget {
  final String empleado;
  final String dni;
  final String entrada;
  final String salida;
  final String coordsEntrada;
  final String coordsSalida;
  final String tiempo;
  final String ordinarias;
  final String incidencias;

  const _SessionCompactCard({
    Key? key,
    required this.empleado,
    required this.dni,
    required this.entrada,
    required this.salida,
    required this.coordsEntrada,
    required this.coordsSalida,
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
    final background = bg ?? themePrimary.withOpacity(.08);
    final foreground = fg ?? themePrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(.25)),
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

  Widget _kv(String label, String value, {IconData? icon, bool isCoordinates = false, required BuildContext context}) {
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
              if (isCoordinates && value != '-')
                _buildExpandableMap(value, context)
              else
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

  Widget _buildExpandableMap(String coordenadas, BuildContext context) {
    return _ExpandableMapWidget(coordenadas: coordenadas);
  }

  Widget _buildMiniMap(String coordenadas, BuildContext context) {
    // Parsear coordenadas
    final coords = coordenadas.split(',');
    if (coords.length != 2) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.grey, size: 24),
        ),
      );
    }

    final lat = double.tryParse(coords[0].trim());
    final lon = double.tryParse(coords[1].trim());

    if (lat == null || lon == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.grey, size: 24),
        ),
      );
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
                          FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lon),
                  initialZoom: 14.0,
                  minZoom: 10.0,
                  maxZoom: 16.0,
                ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.fichar',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lon),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _abrirGoogleMaps(lat, lon),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_in_new,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirGoogleMaps(double lat, double lon) async {
    final url = 'https://www.google.com/maps?q=$lat,$lon';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Error silencioso
    }
  }

  void _abrirMapa(String coordenadas, BuildContext context) {
    // Navegar a la pantalla del mapa
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapViewScreen(
          coordenadas: coordenadas,
          titulo: 'Ubicación del fichaje',
        ),
      ),
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

    // Azul corporativo (ajusta si quieres otro tono)
    const azul = Color(0xFF1565C0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: const Color(0xFFEAEAEA),
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
                  _kv('Fecha y hora', entrada, icon: Icons.login, context: context),
                  const SizedBox(height: 8),
                  _kv('Coordenadas', coordsEntrada, icon: Icons.my_location, isCoordinates: true, context: context),
                ]);
                final salidaSection = _section('Salida', [
                  _kv('Fecha y hora', salida, icon: Icons.logout, context: context),
                  const SizedBox(height: 8),
                  _kv('Coordenadas', coordsSalida, icon: Icons.place_outlined, isCoordinates: true, context: context),
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

// Widget expandible para el mapa
class _ExpandableMapWidget extends StatefulWidget {
  final String coordenadas;

  const _ExpandableMapWidget({
    Key? key,
    required this.coordenadas,
  }) : super(key: key);

  @override
  State<_ExpandableMapWidget> createState() => _ExpandableMapWidgetState();
}

class _ExpandableMapWidgetState extends State<_ExpandableMapWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Parsear coordenadas
    final coords = widget.coordenadas.split(',');
    if (coords.length != 2) {
      return _buildErrorState();
    }

    final lat = double.tryParse(coords[0].trim());
    final lon = double.tryParse(coords[1].trim());

    if (lat == null || lon == null) {
      return _buildErrorState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header clickeable para expandir/contraer
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
                      child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 400 ? 6 : 8,
                vertical: MediaQuery.of(context).size.width < 400 ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width < 400 ? 4 : 6),
                  Expanded(
                    child: Text(
                      widget.coordenadas,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 400 ? 11 : 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width < 400 ? 6 : 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
        ),
        
        // Mapa expandible
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(lat, lon),
                      initialZoom: 14.0,
                      minZoom: 10.0,
                      maxZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.fichar',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lon),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Botón para abrir en Google Maps
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _abrirGoogleMaps(lat, lon),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            'Coordenadas inválidas',
            style: TextStyle(
              fontSize: 13,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _abrirGoogleMaps(double lat, double lon) async {
    final url = 'https://www.google.com/maps?q=$lat,$lon';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Error silencioso
    }
  }
}



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


// ===== Incidencias Tab =====

class IncidenciasTab extends StatelessWidget {
  const IncidenciasTab({Key? key}) : super(key: key);

  void _abrirDialogo(BuildContext context, AdminProvider provider, {Incidencia? incidencia}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFFEAEAEA),
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
            padding: const EdgeInsets.only(bottom: 16),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: provider.incidencias.length,
                  itemBuilder: (context, index) {
                    final inc = provider.incidencias[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 3,
                      color: const Color(0xFFEAEAEA),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _abrirDialogo(context, provider, incidencia: inc),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header con código y estado
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kPrimaryBlue,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      inc.codigo,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: inc.computa ? Colors.green.shade100 : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: inc.computa ? Colors.green.shade300 : Colors.orange.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      inc.computa ? 'Computa horas' : 'No computa',
                                      style: TextStyle(
                                        color: inc.computa ? Colors.green.shade800 : Colors.orange.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                                    tooltip: 'Eliminar incidencia',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: const Color(0xFFEAEAEA),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text(
                                            'Confirmar borrado',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                          ),
                                          content: Text(
                                            '¿Quieres eliminar la incidencia código "${inc.codigo}"?',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                          actionsAlignment: MainAxisAlignment.spaceBetween,
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancelar', style: TextStyle(color: Colors.blue)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                              ),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Eliminar'),
                                            ),
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
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Descripción
                              if (inc.descripcion != null && inc.descripcion!.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    inc.descripcion!,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
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
    return Container(
      color: const Color(0xFFEAEAEA),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: kPrimaryBlue, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: kPrimaryBlue, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
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
                activeColor: Colors.blue,
                checkColor: Colors.white,
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
      ),
    );
  }
}

// HorariosTab.dart
class HorariosTab extends StatefulWidget {
  const HorariosTab({Key? key}) : super(key: key);

  @override
  State<HorariosTab> createState() => _HorariosTabState();
}

class _HorariosTabState extends State<HorariosTab> {
  String? _dniEmpleadoSeleccionado;

  final List<String> _diasSemana = const [
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

  // ======= Helpers de formato =======

  // Recorta HH:MM:SS -> HH:MM (y deja tal cual si ya viene HH:MM)
  String _hhmm(String? t) {
    if (t == null || t.isEmpty) return '';
    final p = t.split(':');
    if (p.length >= 2) return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
    return t;
  }

  // Convierte minutos a HH:MM
  String _fmtMin(int min) {
    final h = (min ~/ 60).toString().padLeft(2, '0');
    final m = (min % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Diferencia en minutos entre HH:MM(SS), manejando cruce de medianoche
  int? _diffMin(String? ini, String? fin) {
    if (ini == null || fin == null || ini.isEmpty || fin.isEmpty) return null;
    final p1 = ini.split(':'), p2 = fin.split(':');
    if (p1.length < 2 || p2.length < 2) return null;
    int s = int.parse(p1[0]) * 60 + int.parse(p1[1]);
    int e = int.parse(p2[0]) * 60 + int.parse(p2[1]);
    if (e < s) e += 24 * 60; // termina al día siguiente
    return e - s;
  }

  Future<void> _abrirDialogoFormulario({HorarioEmpleado? horario}) async {
    final provider = Provider.of<AdminProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _FormularioHorario(
            cifEmpresa: provider.cifEmpresa,
            empleados: provider.empleados,
            horarioExistente: horario,

            // ---- Guardado SINGLE con loader pequeño ----
            onSubmit: (nuevoHorario) async {
              // loader pequeño mientras se guarda un único horario
              final closeSpinner = _showSmallSpinner();
              String? error;
              if (horario == null) {
                error = await provider.addHorarioEmpleado(nuevoHorario);
              } else {
                error = await provider.updateHorarioEmpleado(nuevoHorario);
              }
              closeSpinner();
              if (context.mounted) Navigator.pop(context); // cerrar formulario
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                );
              }
            },

            // ---- Creación MÚLTIPLE con diálogo de progreso ----
            onSubmitMultiple: (nuevosHorarios) async {
              final total = nuevosHorarios.length;
              final progreso = ValueNotifier<int>(0);

              // Diálogo modal no cancelable con barra de progreso
              _showProgressDialog(
                context: context,
                title: 'Creando horarios',
                subtitle: 'Esto puede tardar unos segundos…',
                total: total,
                progreso: progreso,
              );

              String? error;
              try {
                for (int i = 0; i < total; i++) {
                  final h = nuevosHorarios[i];
                  error = await provider.addHorarioEmpleado(h);
                  if (error != null) break;
                  progreso.value = i + 1; // avanzar progreso
                }
              } finally {
                if (Navigator.of(context, rootNavigator: true).canPop()) {
                  Navigator.of(context, rootNavigator: true).pop(); // cerrar diálogo progreso
                }
              }

              if (context.mounted) Navigator.pop(context); // cerrar formulario
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Horarios creados correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // Loader compacto (Circular) para operaciones rápidas
  VoidCallback _showSmallSpinner() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAEA), borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 26, 
                  height: 26, 
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Guardando…', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
    return () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final horariosFiltrados = _dniEmpleadoSeleccionado == null
            ? provider.horarios
            : provider.horarios
                .where((h) => h.dniEmpleado == _dniEmpleadoSeleccionado)
                .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: Text(
                          'Filtrar por empleado',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _dniEmpleadoSeleccionado,
                        icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade600, size: 18),
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        dropdownColor: Colors.white,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        menuMaxHeight: 200,
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Todos los empleados',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          ...provider.empleados.where((e) => e.dni != null).map(
                                (e) => DropdownMenuItem<String?>(
                                  value: e.dni!,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      e.nombre ?? e.usuario,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
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
                  ],
                ),
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
                        final h = horariosFiltrados[index];
                        final empleado = provider.empleados.firstWhere(
                          (e) => e.dni == h.dniEmpleado,
                          orElse: () => Empleado(
                            usuario: '',
                            dni: h.dniEmpleado,
                            nombre: '',
                            cifEmpresa: h.cifEmpresa,
                          ),
                        );
                        final nombreEmpleado = (empleado.nombre?.isNotEmpty ?? false)
                            ? empleado.nombre
                            : empleado.usuario;

                        // Texto de horas ordinarias con fallback
                        final horasTexto = () {
                          if (h.horasOrdinarias != null &&
                              h.horasOrdinarias!.isNotEmpty) {
                            return _hhmm(h.horasOrdinarias); // "07:00:00" -> "07:00"
                          }
                          if (h.horasOrdinariasMin != null) {
                            return _fmtMin(h.horasOrdinariasMin!); // 420 -> "07:00"
                          }
                          final d = _diffMin(h.horaInicio, h.horaFin);
                          return d != null ? _fmtMin(d) : '';
                        }();

                        return Card(
                          color: const Color(0xFFEAEAEA),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: ListTile(
                            // Título compacto: solo horas
                            title: Text(
                              '${_hhmm(h.horaInicio)} - ${_hhmm(h.horaFin)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            // Día + turno (ligero) y debajo empleado
                            subtitle: Text(
                              '${_diasSemana[h.diaSemana]}'
                              '${(h.nombreTurno != null && h.nombreTurno!.isNotEmpty) ? ' · ${h.nombreTurno}' : ''}\n'
                              'Empleado: $nombreEmpleado (${h.dniEmpleado})',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            // A la derecha: pill de horas + acciones
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (horasTexto.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: Colors.blue.shade200),
                                    ),
                                    child: Text(
                                      horasTexto,
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _abrirDialogoFormulario(horario: h),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.redAccent),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: const Color(0xFFEAEAEA),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text(
                                          'Confirmar borrado',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                        ),
                                        content: Text(
                                          '¿Eliminar horario del día ${_diasSemana[h.diaSemana]} para ${h.dniEmpleado}?',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        actionsAlignment: MainAxisAlignment.spaceBetween,
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancelar', style: TextStyle(color: Colors.blue)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            ),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final error = await provider.deleteHorarioEmpleado(
                                        h.id!, h.dniEmpleado,
                                      );
                                      if (error != null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error),
                                            backgroundColor: Colors.redAccent,
                                          ),
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
                  label: const Text('Añadir horario',
                      style: TextStyle(color: Colors.white)),
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

/// Muestra un diálogo de progreso lineal bloqueante.
/// Cerrar manualmente con un `Navigator.pop(rootNavigator: true)`
/// cuando finalice la operación.
void _showProgressDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required int total,
  required ValueNotifier<int> progreso,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAEA),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)],
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: progreso,
            builder: (ctx, current, __) {
              final value = total == 0 ? null : (current / total).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_upload, size: 22),
                      const SizedBox(width: 8),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: Colors.grey[700])),
                  ],
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: value == 0 ? 1e-9 : value,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(total == 0
                      ? 'Preparando…'
                      : 'Progreso: $current / $total'),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _FormularioHorario extends StatefulWidget {
  final String cifEmpresa;
  final List<Empleado> empleados;
  final HorarioEmpleado? horarioExistente;
  final void Function(HorarioEmpleado horario) onSubmit;
  final void Function(List<HorarioEmpleado> horarios)? onSubmitMultiple;

  const _FormularioHorario({
    Key? key,
    required this.cifEmpresa,
    required this.empleados,
    this.horarioExistente,
    required this.onSubmit,
    this.onSubmitMultiple,
  }) : super(key: key);

  @override
  State<_FormularioHorario> createState() => _FormularioHorarioState();
}

class _FormularioHorarioState extends State<_FormularioHorario> {
  final _formKey = GlobalKey<FormState>();

  List<String> _empleadosSeleccionados = [];
  List<int> _diasSeleccionados = [];
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  final TextEditingController _nombreTurnoCtrl = TextEditingController();
  final TextEditingController _margenCtrl = TextEditingController();
  final TextEditingController _margenDespuesCtrl = TextEditingController();

  final List<String> _diasSemana = const [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.horarioExistente != null) {
      _empleadosSeleccionados = [widget.horarioExistente!.dniEmpleado];
      _diasSeleccionados = [widget.horarioExistente!.diaSemana];
      _horaInicio = _parseTime(widget.horarioExistente!.horaInicio);
      _horaFin = _parseTime(widget.horarioExistente!.horaFin);
      _nombreTurnoCtrl.text = widget.horarioExistente?.nombreTurno ?? '';
      _margenCtrl.text =
          widget.horarioExistente?.margenEntradaAntes.toString() ?? "10";
      _margenDespuesCtrl.text =
          widget.horarioExistente?.margenEntradaDespues.toString() ?? "30";
    } else {
      _margenCtrl.text = "10";
      _margenDespuesCtrl.text = "30";
    }
  }

  @override
  void dispose() {
    _nombreTurnoCtrl.dispose();
    _margenCtrl.dispose();
    _margenDespuesCtrl.dispose();
    super.dispose();
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
    final initial = isInicio
        ? _horaInicio ?? const TimeOfDay(hour: 12, minute: 0)
        : _horaFin ?? const TimeOfDay(hour: 12, minute: 0);

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: const SafeArea(
            child: _TimePickerWheel(
              initialHour: 12,
              initialMinute: 0,
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

  bool get isEditing => widget.horarioExistente != null;

  bool _isFormValid() {
    if (_horaInicio == null || _horaFin == null) return false;
    if (_horaInicio!.hour * 60 + _horaInicio!.minute >=
        _horaFin!.hour * 60 + _horaFin!.minute) return false;
    if (!isEditing && _empleadosSeleccionados.isEmpty) return false;
    if (!isEditing && _diasSeleccionados.isEmpty) return false;
    if (int.tryParse(_margenCtrl.text) == null ||
        int.parse(_margenCtrl.text) < 0) return false;
    if (int.tryParse(_margenDespuesCtrl.text) == null ||
        int.parse(_margenDespuesCtrl.text) < 0) return false;
    return true;
  }

  void _guardar() {
    if (!_isFormValid()) return;

    final margen = int.tryParse(_margenCtrl.text) ?? 10;
    final margenDespues = int.tryParse(_margenDespuesCtrl.text) ?? 30;

    if (isEditing) {
      final nuevoHorario = HorarioEmpleado(
        id: widget.horarioExistente?.id,
        dniEmpleado: _empleadosSeleccionados.first,
        cifEmpresa: widget.cifEmpresa,
        diaSemana: _diasSeleccionados.first,
        horaInicio: _formatTime(_horaInicio),
        horaFin: _formatTime(_horaFin),
        nombreTurno: _nombreTurnoCtrl.text.trim(),
        margenEntradaAntes: margen,
        margenEntradaDespues: margenDespues,
      );
      widget.onSubmit(nuevoHorario);
    } else {
      final horarios = <HorarioEmpleado>[];
      for (final dni in _empleadosSeleccionados) {
        for (final dia in _diasSeleccionados) {
          horarios.add(
            HorarioEmpleado(
              dniEmpleado: dni,
              cifEmpresa: widget.cifEmpresa,
              diaSemana: dia,
              horaInicio: _formatTime(_horaInicio),
              horaFin: _formatTime(_horaFin),
              nombreTurno: _nombreTurnoCtrl.text.trim(),
              margenEntradaAntes: margen,
              margenEntradaDespues: margenDespues,
            ),
          );
        }
      }
      if (widget.onSubmitMultiple != null) {
        widget.onSubmitMultiple!(horarios);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final empleadosList = widget.empleados.where((e) => e.dni != null).toList();

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(),
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 32, offset: Offset(0, 12)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 40, color: Colors.blue.shade600),
                              const SizedBox(width: 12),
                              Text(
                                isEditing ? 'Editar horario' : 'Nuevo horario',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Empleados
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Empleados',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: empleadosList.map((emp) {
                              final checked = _empleadosSeleccionados.contains(emp.dni!);
                              return FilterChip(
                                label: Text(emp.nombre ?? emp.usuario),
                                labelStyle: TextStyle(
                                  color: checked ? Colors.white : Colors.blue.shade800,
                                  fontWeight: checked ? FontWeight.bold : FontWeight.normal,
                                ),
                                selected: checked,
                                onSelected: isEditing
                                    ? null
                                    : (val) {
                                        setState(() {
                                          if (emp.dni == null) return;
                                          if (val) {
                                            if (!_empleadosSeleccionados.contains(emp.dni!)) {
                                              _empleadosSeleccionados.add(emp.dni!);
                                            }
                                          } else {
                                            _empleadosSeleccionados.remove(emp.dni!);
                                          }
                                        });
                                      },
                                selectedColor: Colors.blue.shade600,
                                backgroundColor: Colors.blue.shade50,
                                showCheckmark: checked,
                                elevation: checked ? 2 : 0,
                                shadowColor: Colors.black12,
                                disabledColor: Colors.grey.shade200,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Días de la semana
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Días de la semana',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: List.generate(_diasSemana.length, (i) {
                              final checked = _diasSeleccionados.contains(i);
                              return FilterChip(
                                label: Text(_diasSemana[i]),
                                labelStyle: TextStyle(
                                  color: checked ? Colors.white : Colors.blue.shade800,
                                ),
                                selected: checked,
                                onSelected: isEditing
                                    ? null
                                    : (val) {
                                        setState(() {
                                          if (val) {
                                            if (!_diasSeleccionados.contains(i)) {
                                              _diasSeleccionados.add(i);
                                            }
                                          } else {
                                            _diasSeleccionados.remove(i);
                                          }
                                        });
                                      },
                                selectedColor: Colors.blue.shade600,
                                backgroundColor: Colors.blue.shade50,
                                elevation: checked ? 2 : 0,
                                disabledColor: Colors.grey.shade200,
                              );
                            }),
                          ),
                          const SizedBox(height: 18),

                          // Horas
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickHoraPersonalizada(isInicio: true),
                                  borderRadius: BorderRadius.circular(14),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Hora inicio',
                                      filled: true,
                                      fillColor: Colors.blue.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon:
                                          Icon(Icons.access_time, color: Colors.blue.shade400),
                                    ),
                                    child: Text(
                                      _horaInicio != null ? _formatTime(_horaInicio) : 'Selecciona',
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickHoraPersonalizada(isInicio: false),
                                  borderRadius: BorderRadius.circular(14),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Hora fin',
                                      filled: true,
                                      fillColor: Colors.blue.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon:
                                          Icon(Icons.access_time, color: Colors.blue.shade400),
                                    ),
                                    child: Text(
                                      _horaFin != null ? _formatTime(_horaFin) : 'Selecciona',
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Nombre turno
                          TextFormField(
                            controller: _nombreTurnoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre turno (opcional)',
                              filled: true,
                              fillColor: Colors.blue.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Márgenes
                          TextFormField(
                            controller: _margenCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Margen minutos antes (entrada)',
                              filled: true,
                              fillColor: Colors.blue.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              helperText: 'Minutos antes permitidos para fichar (p. ej. 10)',
                            ),
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Obligatorio";
                              final n = int.tryParse(val);
                              if (n == null || n < 0) return "Debe ser número positivo";
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _margenDespuesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Margen minutos después (entrada)',
                              filled: true,
                              fillColor: Colors.blue.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              helperText: 'Minutos después permitidos para fichar (p. ej. 30)',
                            ),
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Obligatorio";
                              final n = int.tryParse(val);
                              if (n == null || n < 0) return "Debe ser número positivo";
                              return null;
                            },
                          ),

                          const SizedBox(height: 32),

                          // Botón acción
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(isEditing ? Icons.save : Icons.add, size: 20),
                              label: Text(
                                isEditing ? 'Guardar cambios' : 'Crear horarios',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                              onPressed: _isFormValid() ? _guardar : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Cerrar
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Selector de hora tipo rueda
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
    // Solución más robusta para evitar overflow en web
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Tamaño máximo garantizado que no cause overflow
    final maxWidth = screenWidth * 0.9; // 90% del ancho de pantalla
    final maxHeight = screenHeight * 0.7; // 70% del alto de pantalla
    
    // Calcular diámetro basado en el espacio disponible
    final wheelDiameter = (maxWidth < 400) 
        ? 80.0  // Tamaño mínimo
        : (maxWidth < 600) 
            ? 100.0  // Tamaño pequeño
            : 120.0; // Tamaño estándar
    
    const TextStyle textStyle = TextStyle(fontSize: 24);

    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      padding: const EdgeInsets.only(top: 20, bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Selecciona la hora',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: wheelDiameter,
                height: wheelDiameter,
                child: ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: 40,
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
                              ? textStyle.copyWith(color: Colors.black, fontWeight: FontWeight.bold)
                              : textStyle.copyWith(color: Colors.grey),
                        ),
                      );
                    },
                    childCount: 24,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(':', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 4),
              SizedBox(
                width: wheelDiameter,
                height: wheelDiameter,
                child: ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: 40,
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
                              ? textStyle.copyWith(color: Colors.black, fontWeight: FontWeight.bold)
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
