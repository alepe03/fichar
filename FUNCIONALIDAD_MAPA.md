# Funcionalidad de Mapa en Coordenadas del Admin

## Descripción
Se ha implementado una nueva funcionalidad que permite al administrador visualizar la ubicación exacta de los fichajes haciendo clic en las coordenadas GPS.

## Características

### 1. Coordenadas Clickables
- Las coordenadas de entrada y salida en la tabla de fichajes del admin ahora son clickables
- Se muestran con un diseño especial (fondo azul claro, borde azul, icono de mapa)
- Al hacer clic, se abre una pantalla de mapa integrada

### 2. Pantalla de Mapa Integrada
- **Mapa interactivo**: Utiliza Google Maps para mostrar la ubicación (configurable)
- **Marcador personalizado**: Muestra un pin azul con las coordenadas exactas
- **Zoom controlado**: Permite hacer zoom desde 10x hasta 18x
- **Centrado automático**: El mapa se centra automáticamente en la ubicación del fichaje
- **Controles avanzados**: Botones de zoom in/out, centrado y navegación

### 3. Funcionalidades Adicionales
- **Botón de Google Maps**: Botón flotante para abrir la ubicación en Google Maps
- **Botón en AppBar**: Icono para abrir en Google Maps desde la barra superior
- **Navegación**: Botón de retroceso para volver a la pantalla del admin

## Implementación Técnica

### Dependencias Agregadas
```yaml
google_maps_flutter: ^2.6.0
```

**Alternativa OpenStreetMap (gratuita):**
```yaml
flutter_map: ^6.1.0
latlong2: ^0.9.0
```

### Archivos Modificados
1. **`lib/screens/admin_screen.dart`**
   - Función `_kv` modificada para soportar coordenadas clickables
   - Función `_abrirMapa` para navegar a la pantalla del mapa
   - Parámetro `isCoordinates` para identificar campos de coordenadas

2. **`lib/screens/map_view_screen.dart`** (NUEVO)
   - Pantalla completa del mapa integrado
   - Integración con OpenStreetMap
   - Marcador personalizado con coordenadas
   - Botones para abrir en Google Maps

### Cómo Funciona
1. El admin ve las coordenadas en la tabla de fichajes
2. Las coordenadas se muestran como botones clickables con estilo especial
3. Al hacer clic, se navega a `MapViewScreen`
4. La pantalla del mapa muestra la ubicación exacta
5. El admin puede hacer zoom y ver detalles del área
6. Opción de abrir en Google Maps para más funcionalidades

## Beneficios

### Para el Administrador
- **Visualización inmediata**: Ve exactamente dónde fichó cada empleado
- **Verificación de ubicación**: Confirma que los empleados están en el lugar correcto
- **Auditoría**: Puede revisar patrones de ubicación de fichajes
- **Interfaz integrada**: No necesita salir de la aplicación

### Para la Empresa
- **Control de presencia**: Verifica que los empleados fichan desde ubicaciones válidas
- **Prevención de fraude**: Detecta fichajes desde ubicaciones incorrectas
- **Reportes visuales**: Mejor comprensión de los datos de fichaje

## Uso

### Ver Coordenadas
1. Ir a la pestaña "Fichajes" en el panel de administración
2. Las coordenadas se muestran en cada tarjeta de sesión de trabajo
3. Las coordenadas válidas aparecen como botones azules clickables

### Abrir Mapa
1. Hacer clic en cualquier coordenada
2. Se abre la pantalla del mapa integrado
3. Usar gestos para hacer zoom y pan
4. Usar botones para abrir en Google Maps

### Navegación
- **Volver**: Botón de retroceso en AppBar
- **Google Maps**: Botón flotante o icono en AppBar

## Compatibilidad
- ✅ **Android**: Funciona completamente
- ✅ **iOS**: Funciona completamente  
- ✅ **Web**: Funciona completamente
- ✅ **Desktop**: Funciona completamente

## Notas Técnicas
- **Google Maps**: Mapa principal con funcionalidades avanzadas (requiere API Key)
- **OpenStreetMap**: Alternativa gratuita sin límites de API
- Las coordenadas se parsean automáticamente del formato "lat, lon"
- Manejo de errores para coordenadas inválidas
- Integración con `url_launcher` para Google Maps externo
- **Configuración**: Ver `GOOGLE_MAPS_CONFIG.md` para detalles de configuración

## Futuras Mejoras
- [ ] Múltiples marcadores en un mapa
- [ ] Ruta entre entrada y salida
- [ ] Filtros por área geográfica
- [ ] Estadísticas de ubicaciones más frecuentes
- [ ] Exportación de mapas en PDF
