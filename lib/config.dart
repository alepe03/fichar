import 'package:flutter/foundation.dart';

// Archivo de configuración global de la app

// URL base de la API para todas las peticiones HTTP
const String BASE_URL = "https://www.trivalle.com/apiFichar/trvFichar.php";

// URL base sin el archivo PHP para servicios que lo requieran
const String BASE_URL_DIR = "https://www.trivalle.com/apiFichar/";

// Configuración específica para web
const bool IS_WEB = kIsWeb;
