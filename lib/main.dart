import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/vcif_screen.dart';

// Punto de entrada de la app
void main() {
  runApp(const FichadorApp());
}

// Widget principal de la aplicación
class FichadorApp extends StatelessWidget {
  const FichadorApp({super.key});

  // Método para decidir la pantalla inicial según si hay un CIF guardado
  Future<Widget> _pantallaInicial() async {
    final prefs = await SharedPreferences.getInstance(); // Obtiene preferencias locales
    final cif = prefs.getString('cif_empresa'); // Lee el valor guardado de 'cif_empresa'
    if (cif != null && cif.isNotEmpty) {
      // Si hay CIF, muestra la pantalla de login
      return const LoginScreen();
    } else {
      // Si no hay CIF, muestra la pantalla para introducir el CIF
      return const VCifScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fichador', // Título de la app
      debugShowCheckedModeBanner: false, // Quita la etiqueta de debug
      theme: ThemeData(
        primaryColor: Colors.blue[800], // Color principal
        scaffoldBackgroundColor: Colors.white, // Fondo de las pantallas
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // Fondo de la AppBar
          foregroundColor: Colors.blue, // Color de los iconos/texto en AppBar
          elevation: 0, // Sin sombra
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
            backgroundColor: Colors.blue, // Color de fondo de los botones
            foregroundColor: Colors.white, // Color del texto de los botones
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
          ),
        ),
      ),
      // Widget inicial: decide qué pantalla mostrar según si hay CIF guardado
      home: FutureBuilder<Widget>(
        future: _pantallaInicial(), // Llama al método para decidir pantalla
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            // Cuando termina de cargar, muestra la pantalla correspondiente
            return snapshot.data!;
          } else {
            // Mientras carga, muestra un indicador de progreso
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
      // Definición de rutas de la app (para navegación con Navigator)
      routes: {
        '/login': (context) => const LoginScreen(), // Ruta para login
        '/cif': (context) => const VCifScreen(),    // Ruta para pantalla de CIF
        // ...otras rutas
      },
    );
  }
}
