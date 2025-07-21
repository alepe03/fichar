import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/vcif_screen.dart';
import 'providers/admin_provider.dart'; // Ajusta esta ruta según tu estructura real

void main() {
  runApp(const FichadorApp());
}

class FichadorApp extends StatelessWidget {
  const FichadorApp({super.key});

  Future<String?> _obtenerCifEmpresa() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cif_empresa');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _obtenerCifEmpresa(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final cifEmpresa = snapshot.data;

          Widget pantallaInicial;
          if (cifEmpresa != null && cifEmpresa.isNotEmpty) {
            // Si hay cif, vamos al login (o podrías ir directo al home si tienes sesión activa)
            pantallaInicial = LoginScreen();
          } else {
            // Si no hay cif, pedimos el cif
            pantallaInicial = const VCifScreen();
          }

          return MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AdminProvider(cifEmpresa ?? ''),
              ),
            ],
            child: MaterialApp(
              title: 'Fichador',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                primaryColor: Colors.blue[800],
                scaffoldBackgroundColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  elevation: 0,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 1.3),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 1.3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.blue, width: 2.5),
                  ),
                  labelStyle: const TextStyle(color: Colors.blue),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                ),
              ),
              home: pantallaInicial,
              routes: {
                '/login': (context) => const LoginScreen(),
                '/cif': (context) => const VCifScreen(),
                // otras rutas aquí
              },
            ),
          );
        } else {
          // Mientras se carga SharedPreferences mostramos spinner
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
      },
    );
  }
}
