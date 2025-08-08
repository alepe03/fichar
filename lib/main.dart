import 'dart:io' show Platform;
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

// Importa el DatabaseHelper para acceder a historicosPendientes()
import 'db/database_helper.dart';
// Servicio de sincronización
import 'services/historico_service.dart';

// Setter global de sqflite:
import 'package:sqflite/sqflite.dart' show databaseFactory;
// Fábricas de implementación:
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' show databaseFactoryFfiWeb;

import 'screens/login_screen.dart';
import 'screens/vcif_screen.dart';
import 'screens/login_empresa_screen.dart';
import 'providers/admin_provider.dart';

/// ScrollBehavior que simula el comportamiento móvil (sin scrollbar visible)
class MobileScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

Future<Widget> _obtenerPantallaInicial() async {
  final prefs = await SharedPreferences.getInstance();
  final cif = prefs.getString('cif_empresa');
  final esTerminalFichaje = prefs.getBool('terminal_fichaje') ?? false;

  if (cif?.isNotEmpty ?? false) {
    if (esTerminalFichaje) {
      // Si está marcado como terminal de fichaje, ir a la pantalla de fichar
      return const EmpresaLoginScreen();
    } else {
      // Si no, login normal
      return const LoginScreen();
    }
  } else {
    // Si no hay CIF, mostrar pantalla de introducción de CIF
    return const VCifScreen();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de SQLite según plataforma
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Carga configuración sincronización
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  final baseUrl = prefs.getString('baseUrl') ?? '';
  final nombreBD = prefs.getString('nombreBD') ?? '';

  // Comprobar conexión real a internet
  Future<bool> _hasInternet() async {
    try {
      final resp = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // Sincronización inicial
  final initial = await Connectivity().checkConnectivity();
  debugPrint('🔍 Estado inicial de red: $initial');
  if (initial != ConnectivityResult.none && await _hasInternet()) {
    debugPrint('⚡ Sincronizando al inicio…');
    try {
      final pendBefore = await DatabaseHelper.instance.historicosPendientes();
      debugPrint('>> Cola inicial: ${pendBefore.map((h) => h.id).toList()}');

      final count = await HistoricoService.sincronizarPendientes(token, baseUrl, nombreBD);
      debugPrint('✅ Sync inicial: $count registros');
    } catch (e) {
      debugPrint('❌ Error en sync inicial: $e');
    }
  }

  // Listener conectividad
  Connectivity().onConnectivityChanged.listen((status) async {
    debugPrint('🔔 Cambió conectividad: $status');
    if (status != ConnectivityResult.none && await _hasInternet()) {
      debugPrint('📶 Conexión con Internet restaurada, lanzando sync…');
      try {
        final pend = await DatabaseHelper.instance.historicosPendientes();
        debugPrint('>> Cola antes de sync: ${pend.map((h) => h.id).toList()}');

        final count = await HistoricoService.sincronizarPendientes(token, baseUrl, nombreBD);
        debugPrint('✅ Sincronizados $count registros');
      } catch (e) {
        debugPrint('❌ Error en sync: $e');
      }
    }
  });

  runApp(const FichadorApp());
}

class FichadorApp extends StatelessWidget {
  const FichadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _obtenerPantallaInicial(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.done) {
          final home = snap.data!;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AdminProvider('')),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                ),
              ),
              scrollBehavior: MobileScrollBehavior(),
              home: home,
              routes: {
                '/login': (_) => const LoginScreen(),
                '/cif': (_) => const VCifScreen(),
                '/empresaLogin': (_) => const EmpresaLoginScreen(),
              },
            ),
          );
        }
        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}
