import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'fichar_screen.dart';

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

    final empleado = await AuthService.loginLocal(
      txtVLoginUsuario.text.trim(),
      txtVLoginPassword.text,
      cifEmpresa,
    );

    if (empleado != null) {
      // Guardar SIEMPRE los datos importantes del empleado
      await prefs.setString('usuario', empleado.usuario);
      await prefs.setString('nombre_empleado', empleado.nombre ?? '');
      await prefs.setString('dni_empleado', empleado.dni ?? '');
      await prefs.setString('id_sucursal', ''); // O el valor real si lo tienes
      await prefs.setString('cif_empresa', empleado.cifEmpresa);

      // --- NUEVO: Guardar token FIJO tras login ---
      await prefs.setString('token', '123456.abcd'); 
      print('[LOGIN] Token global guardado: 123456.abcd');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FicharScreen()),
      );
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
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Recuperar contraseña"),
                              content: const Text("Función de recuperación aún no implementada."),
                              actions: [
                                TextButton(
                                  child: const Text("Cerrar"),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          "Olvidé mi contraseña",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
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
