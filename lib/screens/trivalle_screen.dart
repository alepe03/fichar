import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/empresa.dart';
import '../models/empleado.dart';
import '../services/empleado_service.dart';
import '../services/empresa_service.dart';

class AdminTrivalleScreen extends StatefulWidget {
  const AdminTrivalleScreen({super.key});

  @override
  State<AdminTrivalleScreen> createState() => _AdminTrivalleScreenState();
}

class _AdminTrivalleScreenState extends State<AdminTrivalleScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isLoading = false;

  final _formKeyEmpresa = GlobalKey<FormState>();
  final _formKeyAdmin = GlobalKey<FormState>();

  // Controllers para CREAR
  final _cifController = TextEditingController();
  final _empresaController = TextEditingController();
  final _limiteController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _emailEmpresaController = TextEditingController();
  // NUEVOS
  final _cuotaController = TextEditingController();
  final _observacionesController = TextEditingController();

  // Controllers para Admin
  final _adminUsuarioController = TextEditingController();
  final _adminNombreController = TextEditingController();
  final _adminDniController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminDireccionController = TextEditingController();
  final _adminPoblacionController = TextEditingController();
  final _adminCodigoPostalController = TextEditingController();
  final _adminTelefonoController = TextEditingController();

  // Tab Controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _checkRol();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _checkRol() async {
    final prefs = await SharedPreferences.getInstance();
    final rol = prefs.getString('rol') ?? '';
    if (rol.toLowerCase() != 'trivalle') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    [
      _cifController,
      _empresaController,
      _limiteController,
      _direccionController,
      _telefonoController,
      _codigoPostalController,
      _emailEmpresaController,
      _cuotaController,
      _observacionesController,
      _adminUsuarioController,
      _adminNombreController,
      _adminDniController,
      _adminEmailController,
      _adminPasswordController,
      _adminDireccionController,
      _adminPoblacionController,
      _adminCodigoPostalController,
      _adminTelefonoController,
    ].forEach((c) => c.dispose());
    super.dispose();
  }

  bool _cifValido(String cif) {
    final regExp = RegExp(r'^[A-Z]\d{7}[A-Z0-9]$');
    return regExp.hasMatch(cif);
  }

  double? _parseCuota(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  void _limpiarCampos() {
    _cifController.clear();
    _empresaController.clear();
    _limiteController.clear();
    _direccionController.clear();
    _telefonoController.clear();
    _codigoPostalController.clear();
    _emailEmpresaController.clear();
    _cuotaController.clear();
    _observacionesController.clear();

    _adminUsuarioController.clear();
    _adminNombreController.clear();
    _adminDniController.clear();
    _adminEmailController.clear();
    _adminPasswordController.clear();
    _adminDireccionController.clear();
    _adminPoblacionController.clear();
    _adminCodigoPostalController.clear();
    _adminTelefonoController.clear();
  }

  Future<void> _crearEmpresaYAdmin() async {
    if (!_formKeyEmpresa.currentState!.validate() ||
        !_formKeyAdmin.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final empresa = Empresa(
        cifEmpresa: _cifController.text.trim().toUpperCase(),
        nombre: _empresaController.text.trim(),
        direccion: _direccionController.text.trim().isEmpty
            ? null
            : _direccionController.text.trim(),
        telefono: _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        codigoPostal: _codigoPostalController.text.trim().isEmpty
            ? null
            : _codigoPostalController.text.trim(),
        email: _emailEmpresaController.text.trim().isEmpty
            ? null
            : _emailEmpresaController.text.trim(),
        basedatos: null,
        // NUEVOS
        cuota: _parseCuota(_cuotaController.text),
        observaciones: _observacionesController.text.trim().isEmpty
            ? null
            : _observacionesController.text.trim(),
      );
      final limiteUsuarios = int.parse(_limiteController.text.trim());

      await EmpresaService.insertarEmpresaRemoto(
        empresa: empresa,
        token: token,
        maxUsuarios: limiteUsuarios,
      );

      final adminEmpleado = Empleado(
        usuario: _adminUsuarioController.text.trim(),
        cifEmpresa: empresa.cifEmpresa,
        nombre: _adminNombreController.text.trim(),
        dni: _adminDniController.text.trim(),
        email: _adminEmailController.text.trim(),
        rol: 'admin',
        passwordHash: _adminPasswordController.text.trim(),
        activo: 1,
        puedeLocalizar: 1,
        direccion: _adminDireccionController.text.trim().isEmpty
            ? null
            : _adminDireccionController.text.trim(),
        poblacion: _adminPoblacionController.text.trim().isEmpty
            ? null
            : _adminPoblacionController.text.trim(),
        codigoPostal: _adminCodigoPostalController.text.trim().isEmpty
            ? null
            : _adminCodigoPostalController.text.trim(),
        telefono: _adminTelefonoController.text.trim().isEmpty
            ? null
            : _adminTelefonoController.text.trim(),
      );

      await EmpleadoService.insertarEmpleadoRemoto(
        empleado: adminEmpleado,
        token: token,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Empresa y administrador creados correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      _limpiarCampos();
      setState(() => _currentStep = 0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputStyle(String label, IconData icon, Color color) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      labelText: label,
      prefixIcon: Icon(icon, color: color),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  void _mostrarDialogoEditar(Empresa empresa) {
    final cifCtrl = TextEditingController(text: empresa.cifEmpresa);
    final nombreCtrl = TextEditingController(text: empresa.nombre);
    final direccionCtrl = TextEditingController(text: empresa.direccion ?? '');
    final telefonoCtrl = TextEditingController(text: empresa.telefono ?? '');
    final cpCtrl = TextEditingController(text: empresa.codigoPostal ?? '');
    final emailCtrl = TextEditingController(text: empresa.email ?? '');
    final bdCtrl = TextEditingController(text: empresa.basedatos ?? '');
    final limiteCtrl =
        TextEditingController(text: empresa.maxUsuarios?.toString() ?? '');
    // NUEVOS
    final cuotaCtrl = TextEditingController(
        text: (empresa.cuota == null) ? '' : empresa.cuota!.toString().replaceAll('.', ','));
    final observacionesCtrl =
        TextEditingController(text: empresa.observaciones ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFEAEAEA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Editar ${empresa.nombre}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: cifCtrl,
                decoration: _inputStyle('CIF (no editable)', Icons.confirmation_num, Colors.grey),
                enabled: false,
              ),
              const SizedBox(height: 8),
              TextField(controller: nombreCtrl, decoration: _inputStyle('Nombre', Icons.business, Colors.blue)),
              const SizedBox(height: 12),
              TextField(controller: limiteCtrl, decoration: _inputStyle('Límite Usuarios', Icons.people, Colors.blue), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: direccionCtrl, decoration: _inputStyle('Dirección', Icons.place, Colors.blue)),
              const SizedBox(height: 12),
              TextField(controller: telefonoCtrl, decoration: _inputStyle('Teléfono', Icons.phone, Colors.blue)),
              const SizedBox(height: 12),
              TextField(controller: cpCtrl, decoration: _inputStyle('Código Postal', Icons.markunread_mailbox, Colors.blue)),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: _inputStyle('Email', Icons.email, Colors.blue)),
              const SizedBox(height: 12),
              TextField(controller: bdCtrl, decoration: _inputStyle('Base de Datos', Icons.storage, Colors.blue)),
              const SizedBox(height: 12),
              // NUEVOS
              TextField(
                controller: cuotaCtrl,
                decoration: _inputStyle('Cuota (€)', Icons.euro, Colors.blue),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: observacionesCtrl,
                maxLines: 3,
                decoration: _inputStyle('Observaciones (interno)', Icons.notes, Colors.blue),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            onPressed: () async {
              final token = await _getToken();
              final nuevaEmpresa = Empresa(
                cifEmpresa: empresa.cifEmpresa,
                nombre: nombreCtrl.text.trim(),
                direccion: direccionCtrl.text.trim().isEmpty ? null : direccionCtrl.text.trim(),
                telefono: telefonoCtrl.text.trim().isEmpty ? null : telefonoCtrl.text.trim(),
                codigoPostal: cpCtrl.text.trim().isEmpty ? null : cpCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                basedatos: bdCtrl.text.trim().isEmpty ? null : bdCtrl.text.trim(),
                // NUEVOS
                cuota: _parseCuota(cuotaCtrl.text),
                observaciones: observacionesCtrl.text.trim().isEmpty
                    ? null
                    : observacionesCtrl.text.trim(),
              );
              try {
                await EmpresaService.actualizarEmpresaRemoto(
                  empresa: nuevaEmpresa,
                  maxUsuarios: int.parse(limiteCtrl.text),
                  token: token,
                );
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {}); // recarga la lista
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Empresa actualizada'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text(
              'Guardar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabEditarEmpresas() {
    return FutureBuilder<List<Empresa>>(
      future: _getToken().then((t) => EmpresaService.listarEmpresasRemoto(token: t)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final empresas = snapshot.data ?? [];
        if (empresas.isEmpty) {
          return const Center(child: Text('No hay empresas registradas'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: empresas.length,
          itemBuilder: (_, i) {
            final e = empresas[i];
            return Card(
              color: const Color(0xFFEAEAEA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  e.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'CIF: ${e.cifEmpresa} • Límite: ${e.maxUsuarios ?? "-"}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF2196F3), size: 22),
                  onPressed: () => _mostrarDialogoEditar(e),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tabCrearEmpresa() {
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: () {
        if (_currentStep == 0) {
          if (_formKeyEmpresa.currentState!.validate()) {
            setState(() => _currentStep += 1);
          }
        } else if (_currentStep == 1) {
          if (_formKeyAdmin.currentState!.validate()) {
            setState(() => _currentStep += 1);
          }
        } else {
          _crearEmpresaYAdmin();
        }
      },
      onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep -= 1) : null,
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _currentStep == 2
                      ? (_isLoading ? 'Procesando...' : 'Crear Empresa')
                      : 'Continuar',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text(
                    'Atrás',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('Datos Empresa'),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Form(
              key: _formKeyEmpresa,
              child: Column(
                children: [
                  TextFormField(
                    controller: _cifController,
                    decoration: _inputStyle('CIF Empresa', Icons.confirmation_num, Colors.blue),
                    maxLength: 9,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Introduce el CIF';
                      if (!_cifValido(v)) return 'Formato CIF incorrecto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _empresaController,
                    decoration: _inputStyle('Nombre Empresa', Icons.business, Colors.blue),
                    validator: (v) => v == null || v.isEmpty ? 'Introduce el nombre' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _limiteController,
                    decoration: _inputStyle('Límite Usuarios', Icons.people, Colors.blue),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Introduce límite';
                      if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Valor no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _direccionController, decoration: _inputStyle('Dirección (opcional)', Icons.place, Colors.blue)),
                  const SizedBox(height: 16),
                  TextFormField(controller: _telefonoController, decoration: _inputStyle('Teléfono (opcional)', Icons.phone, Colors.blue), keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  TextFormField(controller: _codigoPostalController, decoration: _inputStyle('Código Postal (opcional)', Icons.markunread_mailbox, Colors.blue), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextFormField(controller: _emailEmpresaController, decoration: _inputStyle('Email Empresa (opcional)', Icons.email, Colors.blue), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  // NUEVOS
                  TextFormField(
                    controller: _cuotaController,
                    decoration: _inputStyle('Cuota (€) (opcional)', Icons.euro, Colors.blue),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final d = _parseCuota(v);
                      if (d == null || d < 0) return 'Cuota no válida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _observacionesController,
                    maxLines: 3,
                    decoration: _inputStyle('Observaciones (interno, opcional)', Icons.notes, Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
        Step(
          title: const Text('Administrador'),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Form(
              key: _formKeyAdmin,
              child: Column(
                children: [
                  TextFormField(controller: _adminUsuarioController, decoration: _inputStyle('Usuario Admin', Icons.person, Colors.orange), validator: (v) => v == null || v.isEmpty ? 'Introduce usuario' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminNombreController, decoration: _inputStyle('Nombre y Apellidos', Icons.account_circle, Colors.orange), validator: (v) => v == null || v.isEmpty ? 'Introduce nombre' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminDniController, decoration: _inputStyle('DNI', Icons.badge_outlined, Colors.orange), validator: (v) => v == null || v.isEmpty ? 'Introduce DNI' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminEmailController, decoration: _inputStyle('Email', Icons.email, Colors.orange), validator: (v) { if (v == null || v.isEmpty) return 'Introduce email'; if (!v.contains('@')) return 'Email no válido'; return null; }),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminPasswordController, obscureText: true, decoration: _inputStyle('Contraseña', Icons.lock, Colors.orange), validator: (v) => v != null && v.length >= 6 ? null : 'Mínimo 6 caracteres'),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminDireccionController, decoration: _inputStyle('Dirección (opcional)', Icons.place, Colors.orange)),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminPoblacionController, decoration: _inputStyle('Población (opcional)', Icons.location_city, Colors.orange)),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminCodigoPostalController, decoration: _inputStyle('Código Postal (opcional)', Icons.markunread_mailbox, Colors.orange), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adminTelefonoController, decoration: _inputStyle('Teléfono (opcional)', Icons.phone, Colors.orange), keyboardType: TextInputType.phone),
                ],
              ),
            ),
          ),
        ),
        Step(
          title: const Text('Confirmación'),
          content: _isLoading ? const Center(child: CircularProgressIndicator()) : const Text('Revisa los datos y pulsa continuar para crear la empresa y el administrador.', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración Trivalle'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Crear Empresa'),
            Tab(text: 'Editar Empresas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _tabCrearEmpresa(),
          _tabEditarEmpresas(),
        ],
      ),
    );
  }
}
