import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';

import '../config.dart';
import '../services/auth_service.dart';
import 'home_screen_admin.dart';
import 'home_screen.dart';
import 'supervisor_screen.dart';
import 'vcif_screen.dart';
import '../providers/admin_provider.dart';
import '../models/empleado.dart';
import 'trivalle_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController txtVLoginUsuario = TextEditingController();
  final TextEditingController txtVLoginPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool vaIsLoading = false;
  bool vaObscurePassword = true;
  bool vaRecordarUsuario = false;
  String? vaErrorMessage;

  List<String> listaCifs = [];
  String? cifSeleccionado;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    _loadCifs();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioGuardado = prefs.getString('usuario_recordado');
    final passwordGuardado = prefs.getString('password_recordado');
    if ((usuarioGuardado?.isNotEmpty ?? false) ||
        (passwordGuardado?.isNotEmpty ?? false)) {
      setState(() {
        txtVLoginUsuario.text = usuarioGuardado ?? '';
        txtVLoginPassword.text = passwordGuardado ?? '';
        vaRecordarUsuario = true;
      });
    }
  }

  Future<void> _loadCifs() async {
    final prefs = await SharedPreferences.getInstance();
    final cifs = prefs.getStringList('cif_empresa_list');
    final ultimoCif = prefs.getString('cif_empresa');

    if (cifs != null && cifs.isNotEmpty) {
      setState(() {
        listaCifs = cifs;
        cifSeleccionado = (ultimoCif != null && cifs.contains(ultimoCif))
            ? ultimoCif
            : cifs.first;
      });
    }
  }

  @override
  void dispose() {
    txtVLoginUsuario.dispose();
    txtVLoginPassword.dispose();
    super.dispose();
  }

  Future<Empleado?> obtenerUsuarioRemoto(String usuario, String cif) async {
    try {
      final url =
          Uri.parse('https://tuservidor/api/empleados/$usuario?cif=$cif');
      final response = await HttpClient().getUrl(url).then((r) => r.close());
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        return Empleado.fromMap(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> btnVLoginEntrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (cifSeleccionado == null || cifSeleccionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un CIF')),
      );
      return;
    }

    setState(() {
      vaIsLoading = true;
      vaErrorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final empleadoLocal = await AuthService.loginLocal(
      txtVLoginUsuario.text.trim(),
      txtVLoginPassword.text,
      cifSeleccionado!,
    );

    if (empleadoLocal == null) {
      setState(() {
        vaErrorMessage = "Usuario o contraseña incorrectos.";
        vaIsLoading = false;
      });
      return;
    }

    Empleado? empleadoActualizado;
    try {
      empleadoActualizado = await obtenerUsuarioRemoto(
        txtVLoginUsuario.text.trim(),
        cifSeleccionado!,
      );
    } catch (e) {
      empleadoActualizado = null;
    }

    final usuarioFinal = empleadoActualizado ?? empleadoLocal;

    if (usuarioFinal.activo != 1) {
      setState(() {
        vaErrorMessage = "Tu usuario ha sido dado de baja por el administrador.";
        vaIsLoading = false;
      });
      return;
    }

    if (vaRecordarUsuario) {
      await prefs.setString('usuario_recordado', txtVLoginUsuario.text.trim());
      await prefs.setString('password_recordado', txtVLoginPassword.text);
    } else {
      await prefs.remove('usuario_recordado');
      await prefs.remove('password_recordado');
    }

    await prefs.setString('cif_empresa', cifSeleccionado!);
    await prefs.setString('usuario', usuarioFinal.usuario);
    await prefs.setString('nombre_empleado', usuarioFinal.nombre ?? '');
    await prefs.setString('dni_empleado', usuarioFinal.dni ?? '');
    await prefs.setString('id_sucursal', '');
    await prefs.setString('token', '123456.abcd');
    await prefs.setString('baseUrl', BASE_URL);
    await prefs.setInt('puede_localizar', usuarioFinal.puedeLocalizar);
    await prefs.setString('rol', usuarioFinal.rol ?? '');

    if (!mounted) return;

    final rol = usuarioFinal.rol?.toLowerCase() ?? '';

    if (rol == 'trivalle') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminTrivalleScreen()),
      );
    } else if (rol == 'admin') {
      final adminProvider = AdminProvider(usuarioFinal.cifEmpresa);
      await adminProvider.cargarDatosIniciales();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: adminProvider,
            child: HomeScreenAdmin(
              usuario: usuarioFinal.usuario,
              cifEmpresa: usuarioFinal.cifEmpresa,
            ),
          ),
        ),
      );
    } else if (rol == 'supervisor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                SupervisorScreen(cifEmpresa: usuarioFinal.cifEmpresa)),
      );
    } else {
      final adminProvider = AdminProvider(usuarioFinal.cifEmpresa);
      await adminProvider.cargarDatosIniciales();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: adminProvider,
            child: HomeScreen(
              usuario: usuarioFinal.usuario,
              cifEmpresa: usuarioFinal.cifEmpresa,
            ),
          ),
        ),
      );
    }
    setState(() => vaIsLoading = false);
  }

  void _mostrarDialogoCambiarPassword(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final _formKeyDialog = GlobalKey<FormState>();
    bool loading = false;
    bool ob1 = true, ob2 = true, ob3 = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.blue,
              selectionColor: Color(0x332196F3),
              selectionHandleColor: Colors.blue,
            ),
          ),
          child: StatefulBuilder(builder: (ctx2, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFFEAEAEA), // Fondo gris claro
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Cambiar contraseña",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              content: Form(
                key: _formKeyDialog,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPasswordField(
                      controller: currentPassCtrl,
                      label: "Contraseña actual",
                      icon: Icons.lock_outline,
                      obscure: ob1,
                      onToggle: () => setStateDialog(() => ob1 = !ob1),
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: newPassCtrl,
                      label: "Nueva contraseña",
                      icon: Icons.lock,
                      obscure: ob2,
                      onToggle: () => setStateDialog(() => ob2 = !ob2),
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: confirmPassCtrl,
                      label: "Confirmar nueva contraseña",
                      icon: Icons.lock,
                      obscure: ob3,
                      onToggle: () => setStateDialog(() => ob3 = !ob3),
                      validator: (v) =>
                          v != newPassCtrl.text ? "No coinciden" : null,
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.blue)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          if (!_formKeyDialog.currentState!.validate()) return;
                          setStateDialog(() => loading = true);

                          final cif = cifSeleccionado ?? '';
                          final usuario = txtVLoginUsuario.text.trim();

                          final success = await AuthService.cambiarPassword(
                            usuario: usuario,
                            cifEmpresa: cif,
                            actual: currentPassCtrl.text.trim(),
                            nueva: newPassCtrl.text.trim(),
                          );

                          setStateDialog(() => loading = false);
                          Navigator.pop(ctx2);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? "Contraseña cambiada con éxito"
                                  : "Error al cambiar la contraseña"),
                            ),
                          );
                        },
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Guardar"),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      cursorColor: Colors.blue,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white, // Campos blancos para contraste
        labelText: label,
        labelStyle: const TextStyle(color: Colors.blue),
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
      validator: validator ??
          (v) => v == null || v.isEmpty ? "Campo obligatorio" : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Iniciar sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.blue),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.blue),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const VCifScreen()),
              );
            },
            tooltip: 'Volver al CIF',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                width: ancho > 400 ? 400 : ancho * 0.95,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/iconotrivalle.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),

                      if (listaCifs.isEmpty)
                        const Text(
                          'No hay CIFs disponibles. Ve a la pantalla anterior para añadirlos.',
                          style: TextStyle(color: Colors.red),
                        )
                      else
                        Theme(
                          data: Theme.of(context).copyWith(
                            splashColor: Colors.blue.withOpacity(0.1),
                            hoverColor: Colors.blue.withOpacity(0.05),
                            focusColor: Colors.blue.withOpacity(0.1),
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Selecciona CIF',
                              labelStyle: const TextStyle(color: Colors.blue),
                              prefixIcon: const Icon(Icons.business, color: Colors.blue),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                            value: cifSeleccionado,
                            iconEnabledColor: Colors.blue,
                            dropdownColor: Color(0xFFEAEAEA),
                            items: listaCifs
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c, style: const TextStyle(color: Colors.black)),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => cifSeleccionado = v),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Selecciona un CIF'
                                : null,
                          ),
                        ),

                      const SizedBox(height: 20),
                      TextFormField(
                        controller: txtVLoginUsuario,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person, color: Colors.blue),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? "Introduce el usuario"
                            : null,
                        enabled: !vaIsLoading,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: txtVLoginPassword,
                        obscureText: vaObscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              vaObscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.blueGrey,
                            ),
                            onPressed: () => setState(
                                () => vaObscurePassword = !vaObscurePassword),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Introduce la contraseña" : null,
                        enabled: !vaIsLoading,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: vaRecordarUsuario,
                            onChanged: vaIsLoading
                                ? null
                                : (v) => setState(() => vaRecordarUsuario = v!),
                            activeColor: Colors.blue,
                          ),
                          const Text("Recordar usuario"),
                        ],
                      ),
                      if (vaErrorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          vaErrorMessage!,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: vaIsLoading ? null : btnVLoginEntrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: vaIsLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _mostrarDialogoCambiarPassword(context),
                        child: const Text(
                          "Cambiar contraseña",
                          style: TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
