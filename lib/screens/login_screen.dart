import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../config.dart'; // <-- Importa la configuración global
import '../services/auth_service.dart';
import 'home_screen_admin.dart';
import 'home_screen.dart';          // Para empleados
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

  Future<void> _loadCifs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? cifs = prefs.getStringList('cif_empresa_list');
    String? ultimoCif = prefs.getString('cif_empresa');

    if (cifs != null && cifs.isNotEmpty) {
      setState(() {
        listaCifs = cifs;
        if (ultimoCif != null && listaCifs.contains(ultimoCif)) {
          cifSeleccionado = ultimoCif;
        } else {
          cifSeleccionado = listaCifs.first;
        }
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

    if (cifSeleccionado == null || cifSeleccionado!.isEmpty) {
      setState(() {
        vaErrorMessage = 'Debes seleccionar un CIF.';
      });
      return;
    }

    setState(() {
      vaIsLoading = true;
      vaErrorMessage = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();

    final empleado = await AuthService.loginLocal(
      txtVLoginUsuario.text.trim(),
      txtVLoginPassword.text,
      cifSeleccionado!,
    );

    if (empleado != null) {
      // Guardar usuario y contraseña si se seleccionó recordar usuario
      if (vaRecordarUsuario) {
        await prefs.setString('usuario_recordado', txtVLoginUsuario.text.trim());
        await prefs.setString('password_recordado', txtVLoginPassword.text);
      } else {
        await prefs.remove('usuario_recordado');
        await prefs.remove('password_recordado');
      }

      // Guardar datos clave en SharedPreferences
      await prefs.setString('cif_empresa', cifSeleccionado!);
      await prefs.setString('usuario', empleado.usuario);
      await prefs.setString('nombre_empleado', empleado.nombre ?? '');
      await prefs.setString('dni_empleado', empleado.dni ?? '');
      await prefs.setString('id_sucursal', '');

      // Guardar token y URL base desde config.dart
      await prefs.setString('token', '123456.abcd'); // Cambia este token por el real
      await prefs.setString('baseUrl', BASE_URL);

      print('[LOGIN] Token global guardado: 123456.abcd');
      print('[LOGIN] URL base guardada: $BASE_URL');

      await prefs.setInt('puede_localizar', empleado.puedeLocalizar);

      if (!mounted) return;

      final rol = empleado.rol?.toLowerCase() ?? '';
      print('[LOGIN] Rol usuario: $rol');

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
      } else if (rol == 'empleado') {
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
      } else {
        setState(() {
          vaErrorMessage = 'Rol no autorizado.';
        });
      }
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
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Selecciona CIF',
                        border: OutlineInputBorder(),
                      ),
                      value: cifSeleccionado,
                      items: listaCifs
                          .map((cif) => DropdownMenuItem(
                                value: cif,
                                child: Text(cif),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          cifSeleccionado = val;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Selecciona un CIF';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 20),
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
