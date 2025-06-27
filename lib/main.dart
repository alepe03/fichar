import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/vcif_screen.dart';

void main() {
  runApp(const FichadorApp());
}

class FichadorApp extends StatelessWidget {
  const FichadorApp({super.key});

  // Decide la pantalla inicial según si hay CIF guardado
  Future<Widget> _pantallaInicial() async {
    final prefs = await SharedPreferences.getInstance();
    final cif = prefs.getString('cif_empresa');
    if (cif != null && cif.isNotEmpty) {
      return const LoginScreen();
    } else {
      return const VCifScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      // Esta es la clave:
      home: FutureBuilder<Widget>(
        future: _pantallaInicial(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return snapshot.data!;
          } else {
            // Pantalla de carga mientras se decide
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
      // Ojo: si usas rutas, puedes definirlas aquí
      routes: {
        '/login': (context) => const LoginScreen(),
        '/cif': (context) => const VCifScreen(),
        // ...otras rutas
      },
    );
  }
}
