# Configuración de Base de Datos - Fichar App

## Cambiar Base de Datos Fácilmente

Esta aplicación está diseñada para que puedas cambiar la base de datos **desde un solo lugar** sin tener que buscar y reemplazar en todo el código.

### 📍 Ubicación de la Configuración

Toda la configuración está centralizada en el archivo:
```
lib/config.dart
```

### 🔧 Variables a Modificar

Para cambiar de base de datos, solo necesitas modificar estas constantes:

```dart
// ====================== CONFIGURACIÓN DE BASE DE DATOS ======================
const String DATABASE_NAME = 'qame400';           // ← Cambia aquí el nombre
const String DATABASE_SERVER = 'qame400.trivalle.com';  // ← Cambia aquí el servidor
const String DATABASE_USER = 'qame400';           // ← Cambia aquí el usuario
const String DATABASE_PASSWORD = 'Sistema01.';    // ← Cambia aquí la contraseña

// ====================== CONFIGURACIÓN DE TOKEN ======================
const String API_TOKEN = 'LojGUjH5C3Pifi5l6vck';  // ← Cambia aquí el token
```

### 📝 Ejemplo de Cambio

Si quieres cambiar de `qame400` a `nueva_bd`:

**ANTES:**
```dart
const String DATABASE_NAME = 'qame400';
const String DATABASE_SERVER = 'qame400.trivalle.com';
const String DATABASE_USER = 'qame400';
```

**DESPUÉS:**
```dart
const String DATABASE_NAME = 'nueva_bd';
const String DATABASE_SERVER = 'nueva_bd.trivalle.com';
const String DATABASE_USER = 'nueva_bd';
```

### 🎯 Cómo Funciona

1. **Configuración Centralizada**: Todas las referencias a la base de datos usan `DatabaseConfig.databaseName`
2. **Sin Hardcodeo**: No hay referencias directas a `'qame400'` en el resto del código
3. **Cambio Automático**: Al modificar `config.dart`, todos los servicios se actualizan automáticamente

### 🔍 Servicios que Usan la Configuración

- ✅ `EmpleadoService` - Descarga y sincronización de empleados
- ✅ `HistoricoService` - Sincronización de fichajes
- ✅ `SucursalService` - Descarga de sucursales
- ✅ `IncidenciaService` - Gestión de incidencias
- ✅ `AdminProvider` - Gestión administrativa
- ✅ `FicharScreen` - Pantalla de fichaje

### 🚀 Ventajas de esta Arquitectura

1. **Mantenimiento Fácil**: Un solo lugar para cambiar la configuración
2. **Sin Errores**: No hay riesgo de olvidar cambiar alguna referencia
3. **Escalabilidad**: Fácil agregar nuevas configuraciones
4. **Legibilidad**: Código más limpio y profesional

### 📱 Uso en el Código

En lugar de escribir:
```dart
// ❌ MAL - Hardcodeado
const nombreBD = 'qame400';
```

Ahora escribimos:
```dart
// ✅ BIEN - Configuración centralizada
final nombreBD = DatabaseConfig.databaseName;
```

### 🔄 Proceso de Cambio

1. Abre `lib/config.dart`
2. Modifica las constantes de base de datos
3. Guarda el archivo
4. ¡Listo! Todos los servicios se actualizan automáticamente

### ⚠️ Notas Importantes

- **Reinicia la app** después de cambiar la configuración
- **Verifica la conectividad** con la nueva base de datos
- **Mantén el formato** de las constantes (comillas, punto y coma)
- **Haz backup** de la configuración anterior

---

**¿Necesitas ayuda?** Revisa los comentarios en `lib/config.dart` para más detalles sobre cada configuración.
