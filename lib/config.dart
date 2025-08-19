import 'package:flutter/foundation.dart';

// Archivo de configuración global de la app

// ====================== CONFIGURACIÓN DE BASE DE DATOS ======================
// 
// Configuración centralizada de la base de datos
// Para cambiar de base de datos, solo modifica estas constantes:
//
const String DATABASE_NAME = 'qame400';
const String DATABASE_SERVER = 'qame400.trivalle.com';
const String DATABASE_USER = 'qame400';
const String DATABASE_PASSWORD = 'Sistema01.';

// ====================== CONFIGURACIÓN DE TOKEN ======================
//
// Token de autenticación para la API
// Para cambiar el token, solo modifica esta constante:
//
const String API_TOKEN = 'LojGUjH5C3Pifi5l6vck';

// ====================== CONFIGURACIÓN DE URLS ======================
//
// URL base de la API para todas las peticiones HTTP
const String BASE_URL = "https://www.trivalle.com/apiFichar/trvFichar.php";

// URL base sin el archivo PHP para servicios que lo requieran
const String BASE_URL_DIR = "https://www.trivalle.com/apiFichar/";

// Configuración específica para web
const bool IS_WEB = kIsWeb;

// ====================== FUNCIONES DE CONFIGURACIÓN ======================
//
// Funciones para obtener la configuración de la base de datos
// Útil para futuras expansiones o cambios dinámicos
//
class DatabaseConfig {
  /// Obtiene el nombre de la base de datos
  static String get databaseName => DATABASE_NAME;
  
  /// Obtiene el servidor de la base de datos
  static String get databaseServer => DATABASE_SERVER;
  
  /// Obtiene el usuario de la base de datos
  static String get databaseUser => DATABASE_USER;
  
  /// Obtiene la contraseña de la base de datos
  static String get databasePassword => DATABASE_PASSWORD;
  
  /// Obtiene el token de la API
  static String get apiToken => API_TOKEN;
  
  /// Obtiene la URL base de la API
  static String get baseUrl => BASE_URL;
  
  /// Obtiene la URL base del directorio de la API
  static String get baseUrlDir => BASE_URL_DIR;
}
