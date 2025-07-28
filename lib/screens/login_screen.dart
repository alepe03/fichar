import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/auth_service.dart';
import 'home_screen_admin.dart';
import 'home_screen.dart';
import 'supervisor_screen.dart';
import 'vcif_screen.dart';
import '../providers/admin_provider.dart';

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

  Future<void> btnVLoginEntrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (cifSeleccionado == null || cifSeleccionado!.isEmpty) {
      setState(() => vaErrorMessage = 'Debes seleccionar un CIF.');
      return;
    }

    setState(() {
      vaIsLoading = true;
      vaErrorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final empleado = await AuthService.loginLocal(
      txtVLoginUsuario.text.trim(),
      txtVLoginPassword.text,
      cifSeleccionado!,
    );

    if (empleado != null) {
      // Recordar credenciales
      if (vaRecordarUsuario) {
        await prefs.setString('usuario_recordado', txtVLoginUsuario.text.trim());
        await prefs.setString('password_recordado', txtVLoginPassword.text);
      } else {
        await prefs.remove('usuario_recordado');
        await prefs.remove('password_recordado');
      }

      // Guardar datos en SharedPreferences
      await prefs.setString('cif_empresa', cifSeleccionado!);
      await prefs.setString('usuario', empleado.usuario);
      await prefs.setString('nombre_empleado', empleado.nombre ?? '');
      await prefs.setString('dni_empleado', empleado.dni ?? '');
      await prefs.setString('id_sucursal', '');
      await prefs.setString('token', '123456.abcd');
      await prefs.setString('baseUrl', BASE_URL);
      await prefs.setInt('puede_localizar', empleado.puedeLocalizar);

      if (!mounted) return;

      final rol = empleado.rol?.toLowerCase() ?? '';
      if (rol == 'admin') {
        final adminProvider = AdminProvider(empleado.cifEmpresa);
        await adminProvider.cargarDatosIniciales();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: adminProvider,
              child: HomeScreenAdmin(
                usuario: empleado.usuario,
                cifEmpresa: empleado.cifEmpresa,
              ),
            ),
          ),
        );
      } else if (rol == 'supervisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SupervisorScreen(cifEmpresa: empleado.cifEmpresa),
          ),
        );
      } else {
        final adminProvider = AdminProvider(empleado.cifEmpresa);
        await adminProvider.cargarDatosIniciales();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: adminProvider,
              child: HomeScreen(
                usuario: empleado.usuario,
                cifEmpresa: empleado.cifEmpresa,
              ),
            ),
          ),
        );
      }
    } else {
      setState(() => vaErrorMessage = "Usuario o contraseña incorrectos.");
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
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text("Cambiar contraseña"),
              content: Form(
                key: _formKeyDialog,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: ob1,
                      decoration: InputDecoration(
                        labelText: "Contraseña actual",
                        suffixIcon: IconButton(
                          icon: Icon(
                              ob1 ? Icons.visibility : Icons.visibility_off),
                          onPressed: () =>
                              setStateDialog(() => ob1 = !ob1),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Obligatorio" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: ob2,
                      decoration: InputDecoration(
                        labelText: "Nueva contraseña",
                        suffixIcon: IconButton(
                          icon: Icon(
                              ob2 ? Icons.visibility : Icons.visibility_off),
                          onPressed: () =>
                              setStateDialog(() => ob2 = !ob2),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? "Mínimo 6 caracteres"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: ob3,
                      decoration: InputDecoration(
                        labelText: "Confirmar nueva contraseña",
                        suffixIcon: IconButton(
                          icon: Icon(
                              ob3 ? Icons.visibility : Icons.visibility_off),
                          onPressed: () =>
                              setStateDialog(() => ob3 = !ob3),
                        ),
                      ),
                      validator: (v) =>
                          v != newPassCtrl.text ? "No coinciden" : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!_formKeyDialog.currentState!.validate())
                            return;
                          setStateDialog(() => loading = true);

                          final prefs = await SharedPreferences.getInstance();
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
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Scaffold(
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
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

                  // Dropdown de CIFs
                  if (listaCifs.isEmpty)
                    const Text(
                      'No hay CIFs disponibles. Ve a la pantalla anterior para añadirlos.',
                      style: TextStyle(color: Colors.red),
                    )
                  else
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Selecciona CIF',
                        border: OutlineInputBorder(),
                      ),
                      value: cifSeleccionado,
                      items: listaCifs
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => cifSeleccionado = v),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Selecciona un CIF' : null,
                    ),

                  const SizedBox(height: 20),
                  // Usuario
                  TextFormField(
                    controller: txtVLoginUsuario,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person, color: Colors.blue),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "Introduce el usuario" : null,
                    enabled: !vaIsLoading,
                  ),

                  const SizedBox(height: 20),
                  // Contraseña
                  TextFormField(
                    controller: txtVLoginPassword,
                    obscureText: vaObscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                      suffixIcon: IconButton(
                        icon: Icon(
                          vaObscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.blueGrey,
                        ),
                        onPressed: () =>
                            setState(() => vaObscurePassword = !vaObscurePassword),
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
                  vaIsLoading
                      ? const CircularProgressIndicator(color: Colors.blue)
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: btnVLoginEntrar,
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
                            child: const Text('Entrar'),
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
    );
  }
}
