import 'package:flutter/foundation.dart';
import '../config.dart';

class WebConfigService {
  /// Obtiene la URL base apropiada según la plataforma
  static String getBaseUrl() {
    if (kIsWeb) {
      // En web, usar la URL completa con el archivo PHP
      return BASE_URL;
    }
    // En móvil/desktop, usar la URL base
    return BASE_URL_DIR;
  }

  /// Obtiene headers apropiados para web
  static Map<String, String> getWebHeaders() {
    if (kIsWeb) {
      return {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': '*/*',
        'Access-Control-Allow-Origin': '*',
      };
    }
    return {
      'Content-Type': 'application/x-www-form-urlencoded',
    };
  }

  /// Verifica si estamos en un entorno de producción web
  static bool isProductionWeb() {
    return kIsWeb && !kDebugMode;
  }

  /// Obtiene timeout apropiado para web
  static Duration getWebTimeout() {
    if (kIsWeb) {
      // En web, timeout más largo por posibles problemas de red
      return const Duration(seconds: 30);
    }
    return const Duration(seconds: 15);
  }

  /// Maneja errores específicos de web
  static String handleWebError(dynamic error) {
    if (kIsWeb) {
      if (error.toString().contains('CORS')) {
        return 'Error de CORS: La API no permite acceso desde este dominio. Contacta al administrador.';
      }
      if (error.toString().contains('Failed to fetch')) {
        return 'Error de conexión: No se pudo conectar con el servidor. Verifica tu conexión a internet.';
      }
      if (error.toString().contains('timeout')) {
        return 'Timeout: La conexión tardó demasiado. Inténtalo de nuevo.';
      }
    }
    return error.toString();
  }
}
