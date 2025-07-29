import 'dart:io' show Platform;
import 'dart:ui' show PointerDeviceKind;                  // ← Importa PointerDeviceKind
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';                    // ← Para manejar gestos si lo necesitas
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1) Trae el setter global de sqflite:
import 'package:sqflite/sqflite.dart' show databaseFactory;
// 2) Trae las fábricas de las dos implementaciones:
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

import 'screens/login_screen.dart';
import 'screens/vcif_screen.dart';
import 'providers/admin_provider.dart';

/// ScrollBehavior que simula el comportamiento móvil (sin scrollbar visible)
class MobileScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // No dibuja la barra de scroll en Web/Desktop
    return child;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // 1) En Web: IndexedDB + WASM
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // 2) En Desktop: SQLite-FFI nativo
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    // 3) En Android/iOS: dejamos el plugin nativo de sqflite
    //    que ya trae su propia databaseFactory
  }

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
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.done) {
          final cif = snap.data;
          final home = (cif?.isNotEmpty ?? false)
              ? const LoginScreen()
              : const VCifScreen();

          return MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AdminProvider(cif ?? ''),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,

              // Forzamos estilo Android en Web/Desktop
              theme: ThemeData(
                platform: TargetPlatform.android,
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
                    borderSide:
                        const BorderSide(color: Colors.blueAccent, width: 1.3),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Colors.blueAccent, width: 1.3),
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
                    textStyle:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                ),
              ),

              // Aplica el comportamiento de scroll móvil
              scrollBehavior: MobileScrollBehavior(),

              home: home,
              routes: {
                '/login': (_) => const LoginScreen(),
                '/cif': (_) => const VCifScreen(),
              },
            ),
          );
        }

        // Mientras carga SharedPreferences
        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}
