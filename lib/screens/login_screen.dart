import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // <-- Añadido para Provider
import '../services/auth_service.dart';
import 'fichar_screen.dart';
import 'admin_screen.dart'; // <-- Ajusta la ruta si tu admin_screen.dart está en otro sitio

// Pantalla de login principal
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

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  // Carga usuario y contraseña recordados si existen
  Future<void> _loadRememberedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? usuarioGuardado = prefs.getString('usuario_recordado');
    String? passwordGuardado = prefs.getString('password_recordado');
    if ((usuarioGuardado != null && usuarioGuardado.isNotEmpty) ||
        (passwordGuardado != null && passwordGuardado.isNotEmpty)) {
      setState(() {
        txtVLoginUsuario.text = usuarioGuardado ?? '';
        txtVLoginPassword.text = passwordGuardado ?? '';
        vaRecordarUsuario = true;
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      vaIsLoading = true;
      vaErrorMessage = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final cifEmpresa = prefs.getString('cif_empresa') ?? '';

    if (cifEmpresa.isEmpty) {
      setState(() {
        vaErrorMessage = "No se ha encontrado el CIF de la empresa. Vuelve a la pantalla anterior.";
        vaIsLoading = false;
      });
      return;
    }

    // Llama al servicio de autenticación local
    final empleado = await AuthService.loginLocal(
      txtVLoginUsuario.text.trim(),
      txtVLoginPassword.text,
      cifEmpresa,
    );

    if (empleado != null) {
      // Guarda usuario y contraseña solo si el checkbox está marcado
      if (vaRecordarUsuario) {
        await prefs.setString('usuario_recordado', txtVLoginUsuario.text.trim());
        await prefs.setString('password_recordado', txtVLoginPassword.text);
      } else {
        await prefs.remove('usuario_recordado');
        await prefs.remove('password_recordado');
      }

      await prefs.setString('usuario', empleado.usuario);
      await prefs.setString('nombre_empleado', empleado.nombre ?? '');
      await prefs.setString('dni_empleado', empleado.dni ?? '');
      await prefs.setString('id_sucursal', '');
      await prefs.setString('cif_empresa', empleado.cifEmpresa);
      await prefs.setString('token', '123456.abcd');
      print('[LOGIN] Token global guardado: 123456.abcd');

      if (!mounted) return;

      // ----- NUEVO: Navegación según el rol del usuario -----
      final bool esAdmin = empleado.rol != null && empleado.rol!.toLowerCase() == 'admin';

      if (esAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => AdminProvider(empleado.cifEmpresa),
              child: AdminScreen(cifEmpresa: empleado.cifEmpresa),
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FicharScreen()),
        );
      }
      // ------------------------------------------------------
    } else {
      setState(() {
        vaErrorMessage = "Usuario o contraseña incorrectos.";
      });
    }

    setState(() {
      vaIsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double ancho = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Iniciar sesión',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: Center(
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
                  const SizedBox(height: 16),
                  // Campo de usuario
                  TextFormField(
                    controller: txtVLoginUsuario,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person, color: Colors.blue),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Introduce el usuario";
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    enabled: !vaIsLoading,
                  ),
                  const SizedBox(height: 20),
                  // Campo de contraseña
                  TextFormField(
                    controller: txtVLoginPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                      suffixIcon: IconButton(
                        icon: Icon(
                          vaObscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.blueGrey,
                        ),
                        onPressed: () {
                          setState(() {
                            vaObscurePassword = !vaObscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Introduce la contraseña";
                      }
                      return null;
                    },
                    obscureText: vaObscurePassword,
                    enabled: !vaIsLoading,
                  ),
                  const SizedBox(height: 12),
                  // Solo el checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: vaRecordarUsuario,
                        onChanged: vaIsLoading
                            ? null
                            : (value) {
                                setState(() {
                                  vaRecordarUsuario = value ?? false;
                                });
                              },
                        activeColor: Colors.blue,
                      ),
                      const Text("Recordar usuario"),
                    ],
                  ),
                  if (vaErrorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      vaErrorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Entrar'),
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
