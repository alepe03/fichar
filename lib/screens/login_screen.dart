import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'fichar_screen.dart';

// Pantalla de login principal
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para los campos de usuario y contraseña
  final TextEditingController txtVLoginUsuario = TextEditingController();
  final TextEditingController txtVLoginPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();  // Clave para el formulario
  bool vaIsLoading = false;                 // Indica si está cargando
  bool vaObscurePassword = true;            // Oculta o muestra la contraseña
  bool vaRecordarUsuario = false;           // Checkbox para recordar usuario
  String? vaErrorMessage;                   // Mensaje de error

  @override
  void dispose() {
    // Libera los controladores cuando se destruye el widget
    txtVLoginUsuario.dispose();
    txtVLoginPassword.dispose();
    super.dispose();
  }

  // Función que se ejecuta al pulsar el botón "Entrar"
  Future<void> btnVLoginEntrar() async {
    FocusScope.of(context).unfocus(); // Quita el foco de los campos
    if (!(_formKey.currentState?.validate() ?? false)) return; // Valida el formulario

    setState(() {
      vaIsLoading = true;    // Muestra el indicador de carga
      vaErrorMessage = null; // Limpia el mensaje de error
    });

    SharedPreferences prefs = await SharedPreferences.getInstance(); // Accede a preferencias
    final cifEmpresa = prefs.getString('cif_empresa') ?? '';        // Obtiene el CIF guardado

    if (cifEmpresa.isEmpty) {
      // Si no hay CIF, muestra error y termina
      setState(() {
        vaErrorMessage = "No se ha encontrado el CIF de la empresa. Vuelve a la pantalla anterior.";
        vaIsLoading = false;
      });
      return;
    }

    // Llama al servicio de autenticación local
    final empleado = await AuthService.loginLocal(
      txtVLoginUsuario.text.trim(), // Usuario ingresado
      txtVLoginPassword.text,       // Contraseña ingresada
      cifEmpresa,                   // CIF de la empresa
    );

    if (empleado != null) {
      // Si el login es correcto, guarda los datos importantes del empleado
      await prefs.setString('usuario', empleado.usuario);
      await prefs.setString('nombre_empleado', empleado.nombre ?? '');
      await prefs.setString('dni_empleado', empleado.dni ?? '');
      await prefs.setString('id_sucursal', ''); // Puedes poner el valor real si lo tienes
      await prefs.setString('cif_empresa', empleado.cifEmpresa);

      // Guarda un token fijo tras login (puedes cambiarlo por el real si tienes backend)
      await prefs.setString('token', '123456.abcd'); 
      print('[LOGIN] Token global guardado: 123456.abcd');

      if (!mounted) return; // Verifica que el widget sigue en pantalla
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FicharScreen()), // Navega a la pantalla principal
      );
    } else {
      // Si el login falla, muestra mensaje de error
      setState(() {
        vaErrorMessage = "Usuario o contraseña incorrectos.";
      });
    }

    setState(() {
      vaIsLoading = false; // Oculta el indicador de carga
    });
  }

  @override
  Widget build(BuildContext context) {
    final double ancho = MediaQuery.of(context).size.width; // Ancho de pantalla
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
            width: ancho > 400 ? 400 : ancho * 0.95, // Ancho máximo del formulario
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
              key: _formKey, // Clave del formulario para validación
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo de la empresa
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
                            vaObscurePassword = !vaObscurePassword; // Muestra/oculta contraseña
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
                  // Checkbox para recordar usuario y botón de recuperar contraseña
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
                  // Mensaje de error si existe
                  if (vaErrorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      vaErrorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Botón de entrar o indicador de carga
                  vaIsLoading
                      ? const CircularProgressIndicator(color: Colors.blue)
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: btnVLoginEntrar, // Llama a la función de login
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
