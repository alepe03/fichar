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

class _AdminTrivalleScreenState extends State<AdminTrivalleScreen> {
  int _currentStep = 0;
  final _formKeyEmpresa = GlobalKey<FormState>();
  final _formKeyAdmin = GlobalKey<FormState>();
  bool _isLoading = false;

  // Empresa
  final _cifController = TextEditingController();
  final _empresaController = TextEditingController();
  final _limiteController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _emailEmpresaController = TextEditingController();

  // Admin
  final _adminUsuarioController = TextEditingController();
  final _adminNombreController = TextEditingController();
  final _adminDniController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminDireccionController = TextEditingController();
  final _adminPoblacionController = TextEditingController();
  final _adminCodigoPostalController = TextEditingController();
  final _adminTelefonoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkRol();
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
    [
      _cifController,
      _empresaController,
      _limiteController,
      _direccionController,
      _telefonoController,
      _codigoPostalController,
      _emailEmpresaController,
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

  void _limpiarCampos() {
    _cifController.clear();
    _empresaController.clear();
    _limiteController.clear();
    _direccionController.clear();
    _telefonoController.clear();
    _codigoPostalController.clear();
    _emailEmpresaController.clear();
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // 🔹 Cierra el teclado al tocar fuera
      child: Scaffold(
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
            )
          ],
        ),
        body: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.blue, // 🔹 Stepper indicador azul
                ),
          ),
          child: Stepper(
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
            onStepCancel: _currentStep > 0
                ? () => setState(() => _currentStep -= 1)
                : null,
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _currentStep == 2
                            ? (_isLoading ? 'Procesando...' : 'Crear Empresa')
                            : 'Continuar',
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Atrás', style: TextStyle(color: Colors.black)),
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
                        TextFormField(
                          controller: _direccionController,
                          decoration: _inputStyle('Dirección (opcional)', Icons.place, Colors.blue),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _telefonoController,
                          decoration: _inputStyle('Teléfono (opcional)', Icons.phone, Colors.blue),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codigoPostalController,
                          decoration: _inputStyle('Código Postal (opcional)', Icons.markunread_mailbox, Colors.blue),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailEmpresaController,
                          decoration: _inputStyle('Email Empresa (opcional)', Icons.email, Colors.blue),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                  ),
                ),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: const Text('Administrador'),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Form(
                    key: _formKeyAdmin,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _adminUsuarioController,
                          decoration: _inputStyle('Usuario Admin', Icons.person, Colors.orange),
                          validator: (v) => v == null || v.isEmpty ? 'Introduce usuario' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminNombreController,
                          decoration: _inputStyle('Nombre y Apellidos', Icons.account_circle, Colors.orange),
                          validator: (v) => v == null || v.isEmpty ? 'Introduce nombre' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminDniController,
                          decoration: _inputStyle('DNI', Icons.badge_outlined, Colors.orange),
                          validator: (v) => v == null || v.isEmpty ? 'Introduce DNI' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminEmailController,
                          decoration: _inputStyle('Email', Icons.email, Colors.orange),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Introduce email';
                            if (!v.contains('@')) return 'Email no válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminPasswordController,
                          obscureText: true,
                          decoration: _inputStyle('Contraseña', Icons.lock, Colors.orange),
                          validator: (v) => v != null && v.length >= 6 ? null : 'Mínimo 6 caracteres',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminDireccionController,
                          decoration: _inputStyle('Dirección (opcional)', Icons.place, Colors.orange),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminPoblacionController,
                          decoration: _inputStyle('Población (opcional)', Icons.location_city, Colors.orange),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminCodigoPostalController,
                          decoration: _inputStyle('Código Postal (opcional)', Icons.markunread_mailbox, Colors.orange),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _adminTelefonoController,
                          decoration: _inputStyle('Teléfono (opcional)', Icons.phone, Colors.orange),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                ),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text('Confirmación'),
                content: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : const Text(
                        'Revisa los datos y pulsa continuar para crear la empresa y el administrador.',
                        style: TextStyle(fontSize: 16),
                      ),
                isActive: _currentStep >= 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
